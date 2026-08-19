/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * foxs-merge - selective OrangeFox .foxs settings merger for POCO X8 Pro (klee)
 *
 * Independent source reconstruction from the validated Build60 runtime contract.
 * This is not copied source from a prior maintainer tree.
 *
 * Important behavior preserved:
 *   - selective allowlist merge only;
 *   - destination inode is truncated in-place, never replaced;
 *   - versioned/headerless/legacy-corrupt/unknown-versioned probes;
 *   - recovery/self-heal of a missing/corrupt header when the source has one;
 *   - non-allowlisted destination keys remain untouched;
 *   - deterministic key ordering after a changed merge;
 *   - exit 10 means "unchanged".
 */

#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define FOX_FILE_MAX        65535u
#define FOX_SERIAL_MAX      65536u
#define FOX_MAX_ENTRIES       256u
#define FOX_MAX_FIELD         512u
#define FOX_MAX_ALLOW         192u
#define FOX_MAX_ALLOW_LEN     511u

struct fox_entry {
    char key[FOX_MAX_FIELD];
    char value[FOX_MAX_FIELD];
};

enum fox_format {
    FOX_FMT_INVALID = 0,
    FOX_FMT_VERSIONED = 1,
    FOX_FMT_HEADERLESS = 2,
    FOX_FMT_LEGACY_CORRUPT = 3,
    FOX_FMT_UNKNOWN_VERSIONED = 4,
};

struct fox_parsed {
    size_t count;
    enum fox_format format;
    size_t prefix_len;
    unsigned char prefix[4];
    struct fox_entry entry[FOX_MAX_ENTRIES];
};

/*
 * Keep the large working sets in BSS, like the Build60 helper did, rather than
 * consuming several hundred KiB of process stack.
 */
static unsigned char g_src_file[FOX_FILE_MAX];
static unsigned char g_dst_file[FOX_FILE_MAX];
static unsigned char g_out_file[FOX_SERIAL_MAX];
static unsigned char g_allow_raw[FOX_FILE_MAX];
static struct fox_parsed g_src;
static struct fox_parsed g_dst;
static struct fox_entry g_legacy_tmp[FOX_MAX_ENTRIES];
static char g_allow[FOX_MAX_ALLOW][FOX_MAX_ALLOW_LEN + 1];

static uint16_t get_le16(const unsigned char *p)
{
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

static void put_le16(unsigned char *p, uint16_t v)
{
    p[0] = (unsigned char)v;
    p[1] = (unsigned char)(v >> 8);
}

static int field_len_valid(uint16_t n)
{
    return n >= 1 && n <= FOX_MAX_FIELD;
}

static int printable_key_bytes(const unsigned char *s, size_t n_including_nul)
{
    size_t i;

    if (n_including_nul < 2 || s[n_including_nul - 1] != '\0')
        return 0;

    for (i = 0; i + 1 < n_including_nul; ++i) {
        if (s[i] < 0x20 || s[i] > 0x7e)
            return 0;
    }

    return 1;
}

/*
 * Native .foxs record:
 *
 *   uint16_le key_len_including_nul
 *   key bytes + NUL
 *   uint16_le value_len_including_nul
 *   value bytes + NUL
 */
static int parse_at(const unsigned char *buf, size_t len, size_t off,
                    struct fox_entry *out, size_t *count, int require_ascii_key)
{
    size_t n = 0;

    while (off < len) {
        uint16_t key_len;
        uint16_t value_len;
        size_t key_chars;
        size_t value_chars;

        if (len - off < 2 || n >= FOX_MAX_ENTRIES)
            return -1;

        key_len = get_le16(buf + off);
        off += 2;

        if (!field_len_valid(key_len) ||
            len - off < key_len ||
            buf[off + key_len - 1] != '\0')
            return -1;

        if (require_ascii_key &&
            !printable_key_bytes(buf + off, key_len))
            return -1;

        key_chars = key_len - 1;
        if (key_chars >= FOX_MAX_FIELD)
            return -1;

        memcpy(out[n].key, buf + off, key_chars);
        out[n].key[key_chars] = '\0';
        off += key_len;

        if (len - off < 2)
            return -1;

        value_len = get_le16(buf + off);
        off += 2;

        if (!field_len_valid(value_len) ||
            len - off < value_len ||
            buf[off + value_len - 1] != '\0')
            return -1;

        value_chars = value_len - 1;
        if (value_chars >= FOX_MAX_FIELD)
            return -1;

        memcpy(out[n].value, buf + off, value_chars);
        out[n].value[value_chars] = '\0';
        off += value_len;
        ++n;
    }

    if (n == 0)
        return -1;

    *count = n;
    return 0;
}

/*
 * Build23-era corrupt/header-stripped signature recovered from Build60:
 *
 *   02 00 01 00 02 00 XX 00
 *
 * If interpreted as native records it becomes a bogus non-printable first
 * key followed by the recoverable settings records. Build60 parsed it in a
 * relaxed mode, then discarded non-printable keys.
 */
static int legacy_corrupt_signature(const unsigned char *buf, size_t len)
{
    return len >= 8 &&
           buf[0] == 0x02 && buf[1] == 0x00 &&
           buf[2] == 0x01 && buf[3] == 0x00 &&
           buf[4] == 0x02 && buf[5] == 0x00 &&
           buf[7] == 0x00;
}

static int key_is_printable_c_string(const char *key)
{
    size_t len = strnlen(key, FOX_MAX_FIELD);
    size_t i;

    if (len == 0 || len >= FOX_MAX_FIELD)
        return 0;

    for (i = 0; i < len; ++i) {
        unsigned char c = (unsigned char)key[i];
        if (c < 0x20 || c > 0x7e)
            return 0;
    }

    return 1;
}

static int parse_file(const unsigned char *buf, size_t len, struct fox_parsed *p)
{
    size_t count = 0;

    memset(p, 0, sizeof(*p));

    /* Native OrangeFox versioned header used by the validated Build60 files. */
    if (len >= 4 &&
        buf[0] == 0x10 && buf[1] == 0x00 &&
        buf[2] == 0x01 && buf[3] == 0x00) {
        if (parse_at(buf, len, 4, p->entry, &p->count, 1) != 0)
            return -1;

        p->format = FOX_FMT_VERSIONED;
        p->prefix_len = 4;
        memcpy(p->prefix, buf, 4);
        return 0;
    }

    /* Known historical corrupt representation. */
    if (legacy_corrupt_signature(buf, len) &&
        parse_at(buf, len, 0, g_legacy_tmp, &count, 0) == 0) {
        size_t i;
        size_t keep = 0;

        for (i = 0; i < count; ++i) {
            if (key_is_printable_c_string(g_legacy_tmp[i].key))
                p->entry[keep++] = g_legacy_tmp[i];
        }

        if (keep > 0) {
            p->count = keep;
            p->format = FOX_FMT_LEGACY_CORRUPT;
            return 0;
        }
    }

    /* Native records with no 4-byte format header. */
    if (parse_at(buf, len, 0, p->entry, &p->count, 1) == 0) {
        p->format = FOX_FMT_HEADERLESS;
        return 0;
    }

    /*
     * A structurally valid 4-byte-prefixed file with an unrecognised prefix.
     * Preserve that prefix if it is already the destination representation.
     */
    if (len >= 5 &&
        parse_at(buf, len, 4, p->entry, &p->count, 1) == 0) {
        p->format = FOX_FMT_UNKNOWN_VERSIONED;
        p->prefix_len = 4;
        memcpy(p->prefix, buf, 4);
        return 0;
    }

    return -1;
}

static int read_bounded(const char *path, unsigned char *buf,
                        size_t capacity, size_t *len)
{
    int fd;
    size_t off = 0;
    unsigned char extra;

    fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0)
        return -1;

    while (off < capacity) {
        ssize_t n = read(fd, buf + off, capacity - off);

        if (n < 0) {
            if (errno == EINTR)
                continue;
            close(fd);
            return -1;
        }

        if (n == 0)
            break;

        off += (size_t)n;
    }

    for (;;) {
        ssize_t n = read(fd, &extra, 1);
        if (n < 0 && errno == EINTR)
            continue;
        if (n != 0) {
            close(fd);
            return -1;
        }
        break;
    }

    close(fd);

    if (off == 0)
        return -1;

    *len = off;
    return 0;
}

/*
 * O_TRUNC is deliberate: it preserves the existing destination inode and thus
 * the ownership/mode/SELinux association expected by the Build60 sync scripts.
 */
static int write_all_trunc(const char *path,
                           const unsigned char *buf, size_t len)
{
    int fd;
    size_t off = 0;

    fd = open(path, O_WRONLY | O_TRUNC | O_CLOEXEC);
    if (fd < 0)
        return -1;

    while (off < len) {
        ssize_t n = write(fd, buf + off, len - off);

        if (n < 0) {
            if (errno == EINTR)
                continue;
            close(fd);
            return -2;
        }

        if (n == 0) {
            close(fd);
            return -2;
        }

        off += (size_t)n;
    }

    if (fsync(fd) != 0) {
        close(fd);
        return -2;
    }

    return close(fd) == 0 ? 0 : -2;
}

static const char *format_name(enum fox_format format)
{
    switch (format) {
    case FOX_FMT_VERSIONED:
        return "versioned";
    case FOX_FMT_HEADERLESS:
        return "headerless";
    case FOX_FMT_LEGACY_CORRUPT:
        return "legacy-corrupt";
    case FOX_FMT_UNKNOWN_VERSIONED:
        return "unknown-versioned";
    default:
        return "invalid";
    }
}

static int probe_file(const char *path)
{
    size_t len = 0;

    if (read_bounded(path, g_src_file, FOX_FILE_MAX, &len) != 0 ||
        parse_file(g_src_file, len, &g_src) != 0) {
        puts("invalid");
        return 20;
    }

    puts(format_name(g_src.format));

    switch (g_src.format) {
    case FOX_FMT_VERSIONED:
        return 0;
    case FOX_FMT_LEGACY_CORRUPT:
        return 11;
    case FOX_FMT_HEADERLESS:
        return 12;
    case FOX_FMT_UNKNOWN_VERSIONED:
        return 13;
    default:
        return 20;
    }
}

static int parse_allowlist(const char *path, size_t *count)
{
    size_t len = 0;
    size_t i = 0;
    size_t n = 0;

    /*
     * The Build60 binary rejects a 65,535-byte allowlist, so its largest
     * accepted list is 65,534 bytes.
     */
    if (read_bounded(path, g_allow_raw, FOX_FILE_MAX - 1, &len) != 0)
        return -1;

    while (i < len) {
        size_t start;
        size_t end;
        size_t copy_len;

        while (i < len &&
               (g_allow_raw[i] == ' '  || g_allow_raw[i] == '\t' ||
                g_allow_raw[i] == '\r' || g_allow_raw[i] == '\n' ||
                g_allow_raw[i] == '\v' || g_allow_raw[i] == '\f'))
            ++i;

        if (i >= len)
            break;

        start = i;

        while (i < len && g_allow_raw[i] != '\r' && g_allow_raw[i] != '\n')
            ++i;

        end = i;

        while (end > start &&
               (g_allow_raw[end - 1] == ' ' || g_allow_raw[end - 1] == '\t'))
            --end;

        if (end > start && g_allow_raw[start] != '#') {
            if (n >= FOX_MAX_ALLOW)
                return -1;

            copy_len = end - start;
            if (copy_len > FOX_MAX_ALLOW_LEN)
                copy_len = FOX_MAX_ALLOW_LEN;

            memcpy(g_allow[n], g_allow_raw + start, copy_len);
            g_allow[n][copy_len] = '\0';
            ++n;
        }

        while (i < len && (g_allow_raw[i] == '\r' || g_allow_raw[i] == '\n'))
            ++i;
    }

    if (n == 0)
        return -1;

    *count = n;
    return 0;
}

static int key_allowed(const char *key, size_t allow_count)
{
    size_t i;

    for (i = 0; i < allow_count; ++i) {
        if (strcmp(key, g_allow[i]) == 0)
            return 1;
    }

    return 0;
}

static int entry_key_compare(const void *a, const void *b)
{
    const struct fox_entry *ea = (const struct fox_entry *)a;
    const struct fox_entry *eb = (const struct fox_entry *)b;
    return strcmp(ea->key, eb->key);
}

static int serialize_file(const struct fox_parsed *p,
                          const unsigned char *prefix, size_t prefix_len,
                          size_t *out_len)
{
    size_t pos = 0;
    size_t i;

    if (prefix_len != 0) {
        if (prefix_len != 4)
            return -1;

        memcpy(g_out_file, prefix, 4);
        pos = 4;
    }

    for (i = 0; i < p->count; ++i) {
        size_t key_len = strnlen(p->entry[i].key, FOX_MAX_FIELD - 1) + 1;
        size_t value_len = strnlen(p->entry[i].value, FOX_MAX_FIELD - 1) + 1;
        size_t need = 2 + key_len + 2 + value_len;

        if (key_len > FOX_MAX_FIELD || value_len > FOX_MAX_FIELD ||
            need > FOX_SERIAL_MAX - pos)
            return -1;

        put_le16(g_out_file + pos, (uint16_t)key_len);
        pos += 2;
        memcpy(g_out_file + pos, p->entry[i].key, key_len);
        pos += key_len;

        put_le16(g_out_file + pos, (uint16_t)value_len);
        pos += 2;
        memcpy(g_out_file + pos, p->entry[i].value, value_len);
        pos += value_len;
    }

    *out_len = pos;
    return 0;
}

static int merge_files(const char *src_path,
                       const char *dst_path,
                       const char *allow_path)
{
    size_t src_len = 0;
    size_t dst_len = 0;
    size_t allow_count = 0;
    size_t prefix_len;
    size_t out_len = 0;
    unsigned char prefix[4] = {0, 0, 0, 0};
    int changed = 0;
    size_t i;

    if (read_bounded(src_path, g_src_file, FOX_FILE_MAX, &src_len) != 0 ||
        read_bounded(dst_path, g_dst_file, FOX_FILE_MAX, &dst_len) != 0) {
        puts("read-error");
        return 65;
    }

    if (parse_file(g_src_file, src_len, &g_src) != 0 ||
        parse_file(g_dst_file, dst_len, &g_dst) != 0) {
        puts("parse-error");
        return 66;
    }

    if (parse_allowlist(allow_path, &allow_count) != 0) {
        puts("allowlist-error");
        return 67;
    }

    for (i = 0; i < g_src.count; ++i) {
        size_t j;

        if (!key_allowed(g_src.entry[i].key, allow_count))
            continue;

        for (j = 0; j < g_dst.count; ++j) {
            if (strcmp(g_src.entry[i].key, g_dst.entry[j].key) == 0)
                break;
        }

        if (j < g_dst.count) {
            if (strcmp(g_src.entry[i].value, g_dst.entry[j].value) != 0) {
                memcpy(g_dst.entry[j].value,
                       g_src.entry[i].value,
                       FOX_MAX_FIELD);
                ++changed;
            }
        } else if (g_dst.count < FOX_MAX_ENTRIES) {
            g_dst.entry[g_dst.count++] = g_src.entry[i];
            ++changed;
        }
    }

    /*
     * Prefix/header policy recovered from Build60:
     *
     * - an existing destination prefix normally wins;
     * - a headerless destination inherits a source prefix and that alone counts
     *   as a repair/change;
     * - legacy-corrupt destination state specifically adopts a source prefix.
     */
    prefix_len = g_dst.prefix_len;

    if (prefix_len == 4)
        memcpy(prefix, g_dst.prefix, 4);
    else if (g_src.prefix_len == 4) {
        memcpy(prefix, g_src.prefix, 4);
        prefix_len = 4;
        ++changed;
    }

    if (g_dst.format == FOX_FMT_LEGACY_CORRUPT && g_src.prefix_len == 4) {
        memcpy(prefix, g_src.prefix, 4);
        prefix_len = 4;
    }

    if (changed == 0) {
        puts("unchanged");
        return 10;
    }

    qsort(g_dst.entry, g_dst.count,
          sizeof(g_dst.entry[0]), entry_key_compare);

    if (serialize_file(&g_dst, prefix, prefix_len, &out_len) != 0) {
        puts("serialize-error");
        return 68;
    }

    if (write_all_trunc(dst_path, g_out_file, out_len) != 0) {
        puts("write-error");
        return 69;
    }

    puts(g_dst.format == FOX_FMT_LEGACY_CORRUPT ? "repaired" : "changed");
    return 0;
}

int main(int argc, char **argv)
{
    if (argc == 3 && strcmp(argv[1], "--probe") == 0)
        return probe_file(argv[2]);

    if (argc == 4)
        return merge_files(argv[1], argv[2], argv[3]);

    fputs("usage: foxs-merge SRC DST ALLOWLIST\n"
          "       foxs-merge --probe FILE\n",
          stderr);
    return 64;
}
