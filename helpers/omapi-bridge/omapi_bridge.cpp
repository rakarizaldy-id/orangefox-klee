/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Recovery OMAPI bridge for POCO X8 Pro (klee).
 *
 * Behavioral reimplementation of the service contract validated in the
 * Build60 golden recovery. This source is intentionally structured around a
 * small backend + Binder façade and does not embed the historical packed ELF.
 */

#include "omapi_protocol.h"

#include <aidl/android/hardware/secure_element/BnSecureElementCallback.h>
#include <aidl/android/hardware/secure_element/ISecureElement.h>
#include <aidl/android/hardware/secure_element/LogicalChannelResponse.h>
#include <aidl/android/se/omapi/BnSecureElementChannel.h>
#include <aidl/android/se/omapi/BnSecureElementReader.h>
#include <aidl/android/se/omapi/BnSecureElementService.h>
#include <aidl/android/se/omapi/BnSecureElementSession.h>
#include <aidl/android/se/omapi/ISecureElementListener.h>
#include <android-base/logging.h>
#include <android-base/properties.h>
#include <android/binder_manager.h>
#include <android/binder_process.h>

#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <utility>
#include <vector>

namespace {
namespace hw = aidl::android::hardware::secure_element;
namespace api = aidl::android::se::omapi;

constexpr char kHardwareService[] =
        "android.hardware.secure_element.ISecureElement/eSE1";
constexpr char kOmapiService[] =
        "android.se.omapi.ISecureElementService/default";
constexpr char kRecoveryReader[] = "eSE1";
constexpr char kReadyProperty[] = "vendor.omapi_bridge.ready";
constexpr std::size_t kMaxGetResponseRounds = 32;

ndk::ScopedAStatus BadArgument(const char* text) {
    return ndk::ScopedAStatus::fromExceptionCodeWithMessage(EX_ILLEGAL_ARGUMENT, text);
}

ndk::ScopedAStatus BadState(const char* text) {
    return ndk::ScopedAStatus::fromExceptionCodeWithMessage(EX_ILLEGAL_STATE, text);
}

ndk::ScopedAStatus MissingObject(const char* text) {
    return ndk::ScopedAStatus::fromExceptionCodeWithMessage(EX_NULL_POINTER, text);
}

ndk::ScopedAStatus NotSupported(const char* text) {
    return ndk::ScopedAStatus::fromExceptionCodeWithMessage(EX_UNSUPPORTED_OPERATION, text);
}

ndk::ScopedAStatus HalFailure(const char* operation, const ndk::ScopedAStatus& status) {
    const char* detail = status.getMessage();
    const std::string message = detail != nullptr ? detail : operation;
    LOG(ERROR) << operation << " failed, exception=" << status.getExceptionCode()
               << " service_error=" << status.getServiceSpecificError()
               << " detail=" << message;

    const int32_t service_error = status.getExceptionCode() == EX_SERVICE_SPECIFIC
            ? status.getServiceSpecificError()
            : hw::ISecureElement::FAILED;
    return ndk::ScopedAStatus::fromServiceSpecificErrorWithMessage(
            service_error, message.c_str());
}

class ConnectionCallback final : public hw::BnSecureElementCallback {
  public:
    ndk::ScopedAStatus onStateChange(bool connected, const std::string& reason) override {
        {
            std::lock_guard<std::mutex> guard(lock_);
            connected_ = connected;
            last_reason_ = reason;
        }
        changed_.notify_all();
        LOG(INFO) << "eSE state: connected=" << connected << " reason=" << reason;
        return ndk::ScopedAStatus::ok();
    }

    bool WaitForConnection(std::chrono::seconds timeout) {
        std::unique_lock<std::mutex> guard(lock_);
        changed_.wait_for(guard, timeout, [this] { return connected_; });
        if (!connected_)
            LOG(ERROR) << "eSE did not become ready: " << last_reason_;
        return connected_;
    }

  private:
    std::mutex lock_;
    std::condition_variable changed_;
    bool connected_ = false;
    std::string last_reason_;
};

class SecureElementLink final {
  public:
    bool Start() {
        ndk::SpAIBinder binder(AServiceManager_waitForService(kHardwareService));
        se_ = hw::ISecureElement::fromBinder(binder);
        if (se_ == nullptr) {
            LOG(ERROR) << "Cannot obtain " << kHardwareService;
            return false;
        }

        callback_ = ndk::SharedRefBase::make<ConnectionCallback>();
        const ndk::ScopedAStatus status = se_->init(callback_);
        if (!status.isOk()) {
            (void)HalFailure("secure-element init", status);
            return false;
        }
        return callback_->WaitForConnection(std::chrono::seconds(10));
    }

    ndk::ScopedAStatus Present(bool* result) {
        std::lock_guard<std::mutex> guard(io_lock_);
        const auto status = se_->isCardPresent(result);
        return status.isOk() ? ndk::ScopedAStatus::ok()
                             : HalFailure("secure-element isCardPresent", status);
    }

    ndk::ScopedAStatus Atr(std::vector<uint8_t>* result) {
        std::lock_guard<std::mutex> guard(io_lock_);
        const auto status = se_->getAtr(result);
        return status.isOk() ? ndk::ScopedAStatus::ok()
                             : HalFailure("secure-element getAtr", status);
    }

    ndk::ScopedAStatus OpenBasic(const std::vector<uint8_t>& aid, int8_t p2,
                                 std::vector<uint8_t>* select_response) {
        std::lock_guard<std::mutex> guard(io_lock_);
        const auto status = se_->openBasicChannel(aid, p2, select_response);
        return status.isOk() ? ndk::ScopedAStatus::ok()
                             : HalFailure("secure-element openBasicChannel", status);
    }

    ndk::ScopedAStatus OpenLogical(const std::vector<uint8_t>& aid, int8_t p2,
                                   hw::LogicalChannelResponse* response) {
        std::lock_guard<std::mutex> guard(io_lock_);
        const auto status = se_->openLogicalChannel(aid, p2, response);
        return status.isOk() ? ndk::ScopedAStatus::ok()
                             : HalFailure("secure-element openLogicalChannel", status);
    }

    ndk::ScopedAStatus Close(int8_t channel) {
        std::lock_guard<std::mutex> guard(io_lock_);
        const auto status = se_->closeChannel(channel);
        return status.isOk() ? ndk::ScopedAStatus::ok()
                             : HalFailure("secure-element closeChannel", status);
    }

    ndk::ScopedAStatus Reset() {
        std::lock_guard<std::mutex> guard(io_lock_);
        const auto status = se_->reset();
        return status.isOk() ? ndk::ScopedAStatus::ok()
                             : HalFailure("secure-element reset", status);
    }

    ndk::ScopedAStatus Exchange(std::vector<uint8_t> command,
                                std::vector<uint8_t>* response) {
        std::lock_guard<std::mutex> guard(io_lock_);
        return ExchangeLocked(std::move(command), response);
    }

  private:
    ndk::ScopedAStatus ExchangeOnceLocked(const std::vector<uint8_t>& command,
                                          std::vector<uint8_t>* response) {
        const auto status = se_->transmit(command, response);
        if (!status.isOk())
            return HalFailure("secure-element transmit", status);
        if (response->size() < 2) {
            return ndk::ScopedAStatus::fromServiceSpecificErrorWithMessage(
                    hw::ISecureElement::IOERROR,
                    "APDU response has no complete status word");
        }
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus ExchangeLocked(std::vector<uint8_t> command,
                                      std::vector<uint8_t>* response) {
        auto status = ExchangeOnceLocked(command, response);
        if (!status.isOk())
            return status;

        if (klee::omapi::RetryWithCorrectLe((*response)[response->size() - 2],
                                            command.size())) {
            command.back() = response->back();
            status = ExchangeOnceLocked(command, response);
            if (!status.isOk())
                return status;
        }

        std::vector<uint8_t> accumulated;
        for (std::size_t round = 0;
             round < kMaxGetResponseRounds &&
             klee::omapi::MoreResponseData((*response)[response->size() - 2]);
             ++round) {
            accumulated.insert(accumulated.end(), response->begin(), response->end() - 2);
            const uint8_t expected = response->back();
            std::vector<uint8_t> follow_up = {command[0], 0xc0, 0x00, 0x00, expected};
            status = ExchangeOnceLocked(follow_up, response);
            if (!status.isOk())
                return status;
        }

        if (!accumulated.empty()) {
            accumulated.insert(accumulated.end(), response->begin(), response->end());
            *response = std::move(accumulated);
        }
        return ndk::ScopedAStatus::ok();
    }

    std::shared_ptr<hw::ISecureElement> se_;
    std::shared_ptr<ConnectionCallback> callback_;
    std::mutex io_lock_;
};

class ChannelImpl final : public api::BnSecureElementChannel {
  public:
    ChannelImpl(std::shared_ptr<SecureElementLink> link, int8_t number,
                std::vector<uint8_t> select_response, std::vector<uint8_t> aid,
                std::shared_ptr<api::ISecureElementListener> listener)
        : link_(std::move(link)),
          number_(number),
          select_response_(std::move(select_response)),
          aid_(std::move(aid)),
          listener_(std::move(listener)) {}

    ndk::ScopedAStatus close() override {
        std::lock_guard<std::mutex> guard(lock_);
        if (closed_)
            return ndk::ScopedAStatus::ok();

        if (number_ == 0) {
            std::vector<uint8_t> ignored;
            (void)link_->Exchange({0x00, 0xa4, 0x04, 0x00, 0x00}, &ignored);
        }

        auto status = link_->Close(number_);
        closed_ = true;
        listener_.reset();
        // Preserve the recovery behavior: failure to close channel zero is ignored.
        return number_ == 0 ? ndk::ScopedAStatus::ok() : status;
    }

    ndk::ScopedAStatus isClosed(bool* result) override {
        std::lock_guard<std::mutex> guard(lock_);
        *result = closed_;
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus isBasicChannel(bool* result) override {
        *result = number_ == 0;
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus getSelectResponse(std::vector<uint8_t>* result) override {
        std::lock_guard<std::mutex> guard(lock_);
        if (closed_)
            return BadState("OMAPI channel is closed");
        *result = select_response_;
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus transmit(const std::vector<uint8_t>& command,
                                std::vector<uint8_t>* response) override {
        std::lock_guard<std::mutex> guard(lock_);
        if (closed_)
            return BadState("OMAPI channel is closed");
        if (command.size() < 4)
            return BadArgument("APDU requires at least four bytes");

        std::vector<uint8_t> routed(command);
        uint8_t cla = 0;
        if (!klee::omapi::RouteClassByte(routed[0], static_cast<uint8_t>(number_), &cla))
            return BadArgument("Logical channel is outside 0..19");
        routed[0] = cla;
        return link_->Exchange(std::move(routed), response);
    }

    ndk::ScopedAStatus selectNext(bool* selected) override {
        std::lock_guard<std::mutex> guard(lock_);
        if (closed_)
            return BadState("OMAPI channel is closed");
        if (aid_.empty())
            return NotSupported("SELECT NEXT needs the AID used to open the channel");

        std::vector<uint8_t> command = {
                0x00, 0xa4, 0x04, 0x02, static_cast<uint8_t>(aid_.size())};
        command.insert(command.end(), aid_.begin(), aid_.end());

        uint8_t cla = 0;
        if (!klee::omapi::RouteClassByte(command[0], static_cast<uint8_t>(number_), &cla))
            return BadArgument("Logical channel is outside 0..19");
        command[0] = cla;

        std::vector<uint8_t> response;
        auto status = link_->Exchange(std::move(command), &response);
        if (!status.isOk())
            return status;

        const uint16_t sw = static_cast<uint16_t>(response[response.size() - 2]) << 8 |
                response.back();
        if (klee::omapi::SelectNextSucceeded(sw)) {
            select_response_ = std::move(response);
            *selected = true;
            return ndk::ScopedAStatus::ok();
        }
        if (klee::omapi::SelectNextNotFound(sw)) {
            *selected = false;
            return ndk::ScopedAStatus::ok();
        }
        return NotSupported("Secure Element returned an unsupported SELECT NEXT status");
    }

  private:
    std::shared_ptr<SecureElementLink> link_;
    const int8_t number_;
    std::vector<uint8_t> select_response_;
    const std::vector<uint8_t> aid_;
    std::shared_ptr<api::ISecureElementListener> listener_;
    std::mutex lock_;
    bool closed_ = false;
};

class SessionImpl final : public api::BnSecureElementSession {
  public:
    explicit SessionImpl(std::shared_ptr<SecureElementLink> link) : link_(std::move(link)) {
        (void)link_->Atr(&atr_);
    }

    ndk::ScopedAStatus getAtr(std::vector<uint8_t>* result) override {
        std::lock_guard<std::mutex> guard(lock_);
        *result = atr_;
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus close() override { return CloseAll(); }

    ndk::ScopedAStatus closeChannels() override {
        std::vector<std::shared_ptr<ChannelImpl>> local;
        {
            std::lock_guard<std::mutex> guard(lock_);
            local = channels_;
            channels_.clear();
        }
        for (const auto& channel : local)
            (void)channel->close();
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus isClosed(bool* result) override {
        std::lock_guard<std::mutex> guard(lock_);
        *result = closed_;
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus openBasicChannel(
            const std::vector<uint8_t>& aid, int8_t p2,
            const std::shared_ptr<api::ISecureElementListener>& listener,
            std::shared_ptr<api::ISecureElementChannel>* result) override {
        auto validation = ValidateOpen(aid, p2, listener);
        if (!validation.isOk())
            return validation;

        std::vector<uint8_t> select_response;
        auto status = link_->OpenBasic(aid, p2, &select_response);
        if (!status.isOk())
            return status;

        auto channel = ndk::SharedRefBase::make<ChannelImpl>(
                link_, 0, std::move(select_response), aid, listener);
        Track(channel);
        *result = std::move(channel);
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus openLogicalChannel(
            const std::vector<uint8_t>& aid, int8_t p2,
            const std::shared_ptr<api::ISecureElementListener>& listener,
            std::shared_ptr<api::ISecureElementChannel>* result) override {
        auto validation = ValidateOpen(aid, p2, listener);
        if (!validation.isOk())
            return validation;

        hw::LogicalChannelResponse response;
        auto status = link_->OpenLogical(aid, p2, &response);
        if (!status.isOk())
            return status;

        auto channel = ndk::SharedRefBase::make<ChannelImpl>(
                link_, response.channelNumber, std::move(response.selectResponse), aid, listener);
        Track(channel);
        *result = std::move(channel);
        return ndk::ScopedAStatus::ok();
    }

  private:
    ndk::ScopedAStatus ValidateOpen(
            const std::vector<uint8_t>& aid, int8_t p2,
            const std::shared_ptr<api::ISecureElementListener>& listener) {
        std::lock_guard<std::mutex> guard(lock_);
        if (closed_)
            return BadState("OMAPI session is closed");
        if (listener == nullptr)
            return MissingObject("OMAPI channel listener must not be null");
        if (!klee::omapi::AidLengthAllowed(aid.size()))
            return BadArgument("AID must be empty or 5..16 bytes long");
        if (!klee::omapi::P2Allowed(static_cast<uint8_t>(p2)))
            return NotSupported("P2 must be 00, 04, 08, or 0c");
        return ndk::ScopedAStatus::ok();
    }

    void Track(const std::shared_ptr<ChannelImpl>& channel) {
        std::lock_guard<std::mutex> guard(lock_);
        channels_.push_back(channel);
    }

    ndk::ScopedAStatus CloseAll() {
        {
            std::lock_guard<std::mutex> guard(lock_);
            if (closed_)
                return ndk::ScopedAStatus::ok();
            closed_ = true;
        }
        return closeChannels();
    }

    std::shared_ptr<SecureElementLink> link_;
    std::vector<uint8_t> atr_;
    std::vector<std::shared_ptr<ChannelImpl>> channels_;
    std::mutex lock_;
    bool closed_ = false;
};

class ReaderImpl final : public api::BnSecureElementReader {
  public:
    explicit ReaderImpl(std::shared_ptr<SecureElementLink> link) : link_(std::move(link)) {}

    ndk::ScopedAStatus isSecureElementPresent(bool* result) override {
        return link_->Present(result);
    }

    ndk::ScopedAStatus openSession(
            std::shared_ptr<api::ISecureElementSession>* result) override {
        bool present = false;
        auto status = link_->Present(&present);
        if (!status.isOk())
            return status;
        if (!present) {
            return ndk::ScopedAStatus::fromServiceSpecificErrorWithMessage(
                    hw::ISecureElement::IOERROR, "Recovery eSE is not present");
        }

        auto session = ndk::SharedRefBase::make<SessionImpl>(link_);
        {
            std::lock_guard<std::mutex> guard(lock_);
            sessions_.push_back(session);
        }
        *result = std::move(session);
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus closeSessions() override {
        std::vector<std::shared_ptr<SessionImpl>> live;
        {
            std::lock_guard<std::mutex> guard(lock_);
            for (const auto& weak : sessions_) {
                if (auto session = weak.lock())
                    live.push_back(std::move(session));
            }
            sessions_.clear();
        }
        for (const auto& session : live)
            (void)session->close();
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus reset(bool* succeeded) override {
        auto status = link_->Reset();
        *succeeded = status.isOk();
        return status;
    }

  private:
    std::shared_ptr<SecureElementLink> link_;
    std::vector<std::weak_ptr<SessionImpl>> sessions_;
    std::mutex lock_;
};

class ServiceImpl final : public api::BnSecureElementService {
  public:
    explicit ServiceImpl(std::shared_ptr<SecureElementLink> link)
        : reader_(ndk::SharedRefBase::make<ReaderImpl>(std::move(link))) {}

    ndk::ScopedAStatus getReaders(std::vector<std::string>* result) override {
        *result = {kRecoveryReader};
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus getReader(
            const std::string& name,
            std::shared_ptr<api::ISecureElementReader>* result) override {
        if (name != kRecoveryReader)
            return BadArgument("Recovery exposes only the eSE1 reader");
        *result = reader_;
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus isNfcEventAllowed(
            const std::string& reader, const std::vector<uint8_t>& aid,
            const std::vector<std::string>& packages, int32_t user_id,
            std::vector<bool>* allowed) override {
        (void)aid;
        (void)user_id;
        if (reader != kRecoveryReader)
            return BadArgument("Unknown recovery Secure Element reader");
        allowed->assign(packages.size(), false);
        return ndk::ScopedAStatus::ok();
    }

  private:
    std::shared_ptr<ReaderImpl> reader_;
};

}  // namespace

int main() {
    android::base::InitLogging(nullptr, android::base::KernelLogger);

    ABinderProcess_setThreadPoolMaxThreadCount(4);
    ABinderProcess_startThreadPool();

    auto link = std::make_shared<SecureElementLink>();
    if (!link->Start()) {
        LOG(ERROR) << "OMAPI bridge: Secure Element backend did not initialize";
        return 1;
    }

    auto service = ndk::SharedRefBase::make<ServiceImpl>(link);
    const binder_status_t registration =
            AServiceManager_addService(service->asBinder().get(), kOmapiService);
    if (registration != STATUS_OK) {
        LOG(ERROR) << "OMAPI bridge: service registration failed, status=" << registration;
        return 1;
    }

    if (!android::base::SetProperty(kReadyProperty, "1")) {
        LOG(ERROR) << "OMAPI bridge: could not set " << kReadyProperty;
        return 1;
    }

    LOG(INFO) << kOmapiService << " ready";
    ABinderProcess_joinThreadPool();
    return 1;
}
