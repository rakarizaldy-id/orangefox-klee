#!/usr/bin/env python3
"""
Fail-closed Build60-equivalent ramdisk patcher for POCO X8 Pro (klee).

This script is intended to run from OrangeFox FOX_LOCAL_CALLBACK_SCRIPT
during the --first-call phase, when OrangeFox passes the recovery ramdisk path.

It patches only:
  - twres/pages/advanced.xml
  - twres/pages/wipe.xml
  - twres/pages/customization.xml
  - /system/bin/twrp -> wrapper, preserving generated ELF as twrp.real

It is idempotent and aborts on unexpected source structure.
"""
from pathlib import Path
import argparse
import os
import re
import shutil
import stat
import sys
import xml.etree.ElementTree as ET

def fail(msg):
    raise SystemExit("KLEE PATCH ERROR: " + msg)

def read(p):
    return p.read_text(encoding="utf-8")

def write(p, s):
    p.write_text(s, encoding="utf-8")

def parse_xml(text, label):
    try:
        ET.fromstring(text)
    except Exception as e:
        fail(f"{label}: XML parse failed: {e}")

def replace_page(text, page_name, replacement):
    pat = re.compile(
        rf'^\t\t<page name="{re.escape(page_name)}">.*?^\t\t</page>',
        re.S | re.M,
    )
    matches = list(pat.finditer(text))
    if len(matches) != 1:
        fail(f"{page_name}: expected exactly one page, found {len(matches)}")
    return text[:matches[0].start()] + replacement.rstrip("\n") + text[matches[0].end():]

def load_fragment(device_dir, name):
    p = device_dir / "patches/orangefox/fragments" / name
    if not p.is_file():
        fail(f"missing fragment: {p}")
    return read(p).rstrip("\n")

def patch_advanced(path, device_dir):
    text = read(path)
    final_entry = load_fragment(device_dir, "advanced-klee-entry.xml")
    final_page = load_fragment(device_dir, "advanced-klee-page.xml")

    # Entry
    if '<listitem name="Klee Tools">' not in text:
        marker = re.compile(
            r'^\t\t\t\t<listitem name="\{@cust_oth\}">.*?^\t\t\t\t</listitem>',
            re.S | re.M,
        )
        ms = list(marker.finditer(text))
        if len(ms) != 1:
            fail(f"advanced.xml: expected one cust_oth anchor, found {len(ms)}")
        m = ms[0]
        text = text[:m.start()] + final_entry + "\n" + text[m.start():]

    # Page
    if '<page name="klee_tools">' not in text:
        marker = "\t</pages>\n</recovery>"
        if text.count(marker) != 1:
            fail("advanced.xml: pages closing anchor mismatch")
        text = text.replace(marker, "\n" + final_page + "\n" + marker, 1)

    # If already partially patched, refuse rather than silently merge wrong content.
    required = [
        '<listitem name="Klee Tools">',
        '<page name="klee_tools">',
        '/system/bin/klee-recovery-selftest',
        '/system/bin/klee-storage-health',
        '/system/bin/klee-clear-logs',
        '/system/bin/klee-fenrir-install',
    ]
    for x in required:
        if text.count(x) != 1:
            fail(f"advanced.xml: required marker count != 1: {x}")

    parse_xml(text, "advanced.xml")
    write(path, text)

def patch_wipe(path, device_dir):
    text = read(path)
    final_slider = load_fragment(device_dir, "wipe-list-slider.xml")
    final_fmt = load_fragment(device_dir, "wipe-formatdata-confirm.xml")
    final_action = load_fragment(device_dir, "wipe-action-page.xml")

    # Replace the wipe page's main slider. Clean upstream uses tw_action=wipe / LIST;
    # already-patched sources contain KleeWipePrep. Scope to the first page only.
    wipe_page_pat = re.compile(r'^\t\t<page name="wipe">.*?^\t\t</page>', re.S | re.M)
    ms = list(wipe_page_pat.finditer(text))
    if len(ms) != 1:
        fail(f"wipe.xml: expected one wipe page, found {len(ms)}")
    wp = ms[0].group(0)
    slider_pat = re.compile(r'^\t\t\t<slider style="slider_action">.*?^\t\t\t</slider>', re.S | re.M)
    sliders = list(slider_pat.finditer(wp))
    if len(sliders) != 1:
        fail(f"wipe.xml: expected one main wipe slider, found {len(sliders)}")
    sm = sliders[0]
    wp2 = wp[:sm.start()] + final_slider + wp[sm.end():]
    text = text[:ms[0].start()] + wp2 + text[ms[0].end():]

    # Replace the two pages whose sequencing is project-specific.
    text = replace_page(text, "formatdata_confirm", final_fmt)
    text = replace_page(text, "wipe_action_page", final_action)

    # Build56+ reset latch: every entrance to wipe_action_page must reset the latch.
    call = '<action function="page">wipe_action_page</action>'
    occurrences = [m.start() for m in re.finditer(re.escape(call), text)]
    if len(occurrences) != 4:
        fail(f"wipe.xml: expected 4 wipe_action_page calls, found {len(occurrences)}")

    lines = text.splitlines(True)
    out = []
    for line in lines:
        if call in line:
            prev_nonblank = next((x for x in reversed(out) if x.strip()), "")
            if 'klee_wipe_queue_done=0' not in prev_nonblank:
                indent = line[:len(line)-len(line.lstrip())]
                out.append(indent + '<action function="set">klee_wipe_queue_done=0</action>\n')
        out.append(line)
    text = "".join(out)

    required = {
        "LIST_PRE": "klee-wipe-prep 'LIST' '%tw_wipe_list%'",
        "DATAMEDIA_PRE": "klee-wipe-prep 'DATAMEDIA' ''",
        "POSTLIST": "klee-wipe-prep 'POSTLIST' '%tw_wipe_list%'",
        "POSTDATAMEDIA": "klee-wipe-prep 'POSTDATAMEDIA' ''",
    }
    for label, marker in required.items():
        if text.count(marker) != 1:
            fail(f"wipe.xml: {label} count != 1")

    if text.count('klee_wipe_queue_done=0') != 4:
        fail("wipe.xml: queue reset count != 4")
    if text.count('<condition var1="klee_wipe_queue_done" var2="1"/>') != 2:
        fail("wipe.xml: queue completion gate count != 2")

    # POSTLIST/POSTDATAMEDIA must live only in wipe_action_page.
    action_block = re.search(
        r'^\t\t<page name="wipe_action_page">.*?^\t\t</page>',
        text, re.S | re.M
    )
    if not action_block:
        fail("wipe.xml: final wipe_action_page missing")
    ab = action_block.group(0)
    for marker in [required["POSTLIST"], required["POSTDATAMEDIA"]]:
        if marker not in ab:
            fail(f"wipe.xml: {marker} not inside wipe_action_page")

    parse_xml(text, "wipe.xml")
    write(path, text)

def patch_customization(path, device_dir):
    text = read(path)
    final_page = load_fragment(device_dir, "customization-apply-splash.xml")
    text = replace_page(text, "apply_splash", final_page)

    marker = '/system/bin/klee_splash_apply.sh'
    if text.count(marker) != 1:
        fail("customization.xml: klee splash backend count != 1")
    parse_xml(text, "customization.xml")
    write(path, text)

def install_twrp_wrapper(ramdisk, device_dir):
    bindir = ramdisk / "system/bin"
    twrp = bindir / "twrp"
    real = bindir / "twrp.real"
    wrapper_src = device_dir / "patches/twrp/twrp-wrapper.sh"

    if not wrapper_src.is_file():
        fail(f"missing TWRP wrapper source: {wrapper_src}")
    wrapper_bytes = wrapper_src.read_bytes()

    # Idempotent state.
    if twrp.is_file() and twrp.read_bytes() == wrapper_bytes:
        if not real.is_file() or real.read_bytes()[:4] != b"\x7fELF":
            fail("twrp wrapper exists but twrp.real ELF is missing")
        return

    if not twrp.is_file():
        fail(f"generated TWRP binary missing: {twrp}")
    data = twrp.read_bytes()
    if data[:4] != b"\x7fELF":
        fail("generated /system/bin/twrp is not an ELF and not our wrapper")
    if real.exists():
        fail("twrp.real already exists while twrp is still ELF")

    twrp.rename(real)
    twrp.write_bytes(wrapper_bytes)
    os.chmod(twrp, 0o755)
    os.chmod(real, 0o755)

def remove_odm_ebusy_binary_hook(ramdisk):
    """Remove Build60's brittle fixed-offset /odm EBUSY LD_PRELOAD hook."""
    service_rc = ramdisk / "init.recovery.service.rc"
    shim = ramdisk / "system/lib64/libodm_ebusy_suppress.so"
    preload = "    setenv LD_PRELOAD /system/lib64/libodm_ebusy_suppress.so\n"

    if service_rc.is_file():
        text = read(service_rc)
        count = text.count("libodm_ebusy_suppress.so")
        if count > 1:
            fail(f"init.recovery.service.rc: unexpected ODM shim reference count {count}")
        if count == 1:
            if preload not in text:
                fail("init.recovery.service.rc: ODM shim appears in an unexpected form")
            write(service_rc, text.replace(preload, "", 1))

    if shim.exists():
        if not shim.is_file():
            fail(f"unexpected ODM shim path type: {shim}")
        shim.unlink()

    if service_rc.is_file() and "libodm_ebusy_suppress.so" in read(service_rc):
        fail("ODM EBUSY binary hook still referenced after cleanup")
    if shim.exists():
        fail("ODM EBUSY binary hook still exists after cleanup")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ramdisk", type=Path)
    ap.add_argument("device_dir", type=Path)
    args = ap.parse_args()

    ramdisk = args.ramdisk.resolve()
    device_dir = args.device_dir.resolve()
    if not ramdisk.is_dir():
        fail(f"ramdisk is not a directory: {ramdisk}")

    targets = {
        "advanced": ramdisk / "twres/pages/advanced.xml",
        "wipe": ramdisk / "twres/pages/wipe.xml",
        "customization": ramdisk / "twres/pages/customization.xml",
    }
    for k, p in targets.items():
        if not p.is_file():
            fail(f"missing {k} target: {p}")

    patch_advanced(targets["advanced"], device_dir)
    patch_wipe(targets["wipe"], device_dir)
    patch_customization(targets["customization"], device_dir)
    install_twrp_wrapper(ramdisk, device_dir)
    remove_odm_ebusy_binary_hook(ramdisk)

    print("KLEE PATCH PASS")
    print(" - advanced.xml: Klee Tools + Fenrir")
    print(" - wipe.xml: Build60 wipe sequencing")
    print(" - customization.xml: vendor_boot-v4 splash")
    print(" - twrp CLI: wrapper + generated twrp.real")
    print(" - ODM EBUSY: source fix only; fixed-offset LD_PRELOAD hook removed")

if __name__ == "__main__":
    main()
