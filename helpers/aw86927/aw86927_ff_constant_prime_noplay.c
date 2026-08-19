// SPDX-License-Identifier: Apache-2.0
//
// Reconstructed from the validated Build60 helper contract for POCO X8 Pro
// (klee). This helper primes the AW86927 Linux force-feedback backend without
// ever issuing a PLAY event.

#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

_Static_assert(sizeof(struct ff_effect) == 48, "unexpected ff_effect ABI");
_Static_assert(sizeof(struct input_event) == 24, "unexpected input_event ABI");
_Static_assert(EVIOCGEFFECTS == 0x80044584UL, "unexpected EVIOCGEFFECTS ABI");
_Static_assert(EVIOCSFF == 0x40304580UL, "unexpected EVIOCSFF ABI");
_Static_assert(EVIOCRMFF == 0x40044581UL, "unexpected EVIOCRMFF ABI");

static const char *const kInputPaths[] = {
    "/dev/input/event0",
    "/dev/input/event1",
    "/dev/input/event2",
    "/dev/input/event3",
    "/dev/input/event4",
    "/dev/input/event5",
    "/dev/input/event6",
    "/dev/input/event7",
};

static int kernel_style_rc(int rc) {
    return rc < 0 ? -errno : rc;
}

static int open_awinic(const char **selected_path) {
    char name[128];

    for (size_t i = 0; i < sizeof(kInputPaths) / sizeof(kInputPaths[0]); ++i) {
        int fd = open(kInputPaths[i], O_RDWR);
        if (fd < 0) {
            continue;
        }

        memset(name, 0, sizeof(name));
        if (ioctl(fd, EVIOCGNAME(sizeof(name)), name) >= 0 &&
            strcmp(name, "awinic_haptic") == 0) {
            *selected_path = kInputPaths[i];
            return fd;
        }

        close(fd);
    }

    return -1;
}

// Build60's tiny helper writes a zero-timestamp input_event and treats a full
// 24-byte write as success. Preserve that observable contract here.
static int emit_event(int fd, uint16_t type, uint16_t code, int32_t value) {
    struct input_event ev;
    memset(&ev, 0, sizeof(ev));
    ev.type = type;
    ev.code = code;
    ev.value = value;

    ssize_t rc = write(fd, &ev, sizeof(ev));
    if (rc == (ssize_t)sizeof(ev)) {
        return 0;
    }
    return rc < 0 ? -errno : (int)rc;
}

int main(void) {
    const char *device = NULL;
    int fd;

    puts("AW86927 CONST PRIME NO-PLAY: strength=0x7fff mode=3");

    fd = open_awinic(&device);
    if (fd < 0) {
        puts("awinic_haptic not found");
        return 1;
    }

    printf("device=%s\n", device);

    int max_effects = 0;
    int ioctl_rc = ioctl(fd, EVIOCGEFFECTS, &max_effects);
    int rc = kernel_style_rc(ioctl_rc);
    printf("EVIOCGEFFECTS rc=%d\n", rc);
    printf("max_effects=%d\n", max_effects);
    if (ioctl_rc < 0 || max_effects <= 0) {
        close(fd);
        return 2;
    }

    // Stage A: upload the stock-like custom periodic effect 7, but do not PLAY.
    // The three signed-16 custom samples match the Build60 helper exactly.
    int16_t custom_data[3] = {7, 0, 0};
    struct ff_effect periodic;
    memset(&periodic, 0, sizeof(periodic));
    periodic.type = FF_PERIODIC;
    periodic.replay.length = 70;
    periodic.u.periodic.waveform = FF_CUSTOM;
    periodic.u.periodic.magnitude = 0x7fff;
    periodic.u.periodic.custom_len = 3;
    periodic.u.periodic.custom_data = custom_data;

    ioctl_rc = ioctl(fd, EVIOCSFF, &periodic);
    rc = kernel_style_rc(ioctl_rc);
    printf("PERIODIC EVIOCSFF rc=%d\n", rc);
    printf("periodic_slot=%d\n", periodic.id);
    if (ioctl_rc < 0) {
        close(fd);
        return 3;
    }

    ioctl_rc = ioctl(fd, EVIOCRMFF, periodic.id);
    rc = kernel_style_rc(ioctl_rc);
    printf("PERIODIC EVIOCRMFF rc=%d\n", rc);
    if (ioctl_rc < 0) {
        close(fd);
        return 4;
    }

    int gain_rc = emit_event(fd, EV_FF, FF_GAIN, 0x7fff);
    int syn_rc = emit_event(fd, EV_SYN, SYN_REPORT, 0);
    printf("FF_GAIN write rc=%d\n", gain_rc);
    printf("SYN_REPORT write rc=%d\n", syn_rc);
    if (gain_rc < 0 || syn_rc < 0) {
        close(fd);
        return 5;
    }

    const struct timespec settle = {
        .tv_sec = 0,
        .tv_nsec = 30000000L,
    };
    (void)nanosleep(&settle, NULL);

    // Stage B: upload FF_CONSTANT to switch the AW86927 driver into the
    // constant-duration backend. Again: upload only, never PLAY.
    struct ff_effect constant;
    memset(&constant, 0, sizeof(constant));
    constant.type = FF_CONSTANT;
    constant.replay.length = 40;
    constant.u.constant.level = 0x7fff;

    ioctl_rc = ioctl(fd, EVIOCSFF, &constant);
    rc = kernel_style_rc(ioctl_rc);
    printf("CONSTANT EVIOCSFF rc=%d\n", rc);
    printf("constant_slot=%d\n", constant.id);
    if (ioctl_rc < 0) {
        close(fd);
        return 6;
    }

    ioctl_rc = ioctl(fd, EVIOCRMFF, constant.id);
    rc = kernel_style_rc(ioctl_rc);
    printf("CONSTANT EVIOCRMFF rc=%d\n", rc);
    if (ioctl_rc < 0) {
        close(fd);
        return 7;
    }

    puts("PRIMED effect11/mode3/strength0x80 NO-PLAY");
    close(fd);
    return 0;
}
