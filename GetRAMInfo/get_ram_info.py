#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Lists the installed RAM modules: slot, brand, part number, size, DDR type
and frequency.

  - Windows (7 to 11): reads the firmware SMBIOS table directly
    (GetSystemFirmwareTable), no administrator rights needed. The DDR type is
    therefore exact even on Windows 7, where WMI does not report it.
  - Linux: reads /sys/firmware/dmi/tables/DMI (requires root: sudo).
  - macOS: queries system_profiler.

When the firmware does not report a value, it is inferred from the module's
part number (or its speed) and followed by "(estimated)".

"MHz" is the marketing figure (e.g. DDR4-2666), which is actually a data rate
in MT/s. The real bus clock is half of it.

Python 3.6 or later (3.8 is the last version available for Windows 7).

Usage:
    python get_ram_info.py
    python get_ram_info.py --csv ram.csv
    sudo python3 get_ram_info.py                 (Linux)
    python get_ram_info.py --dmi-file ram.bin    (saved SMBIOS table, e.g.
                                                  "sudo dmidecode --dump-bin ram.bin")
"""

import argparse
import csv
import io
import platform
import plistlib
import re
import struct
import subprocess
import sys

# JEDEC manufacturer codes as the firmware reports them (bank byte + identifier)
JEDEC_VENDORS = {
    '80CE': 'Samsung',   '80AD': 'SK Hynix',   '802C': 'Micron',
    '859B': 'Crucial',   '0198': 'Kingston',   '029E': 'Corsair',
    '04CD': 'G.Skill',   '04EF': 'Team Group', '04CB': 'ADATA',
    '0443': 'Ramaxel',   '830B': 'Nanya',      '80FE': 'Elpida',
    '8551': 'Qimonda',   '80C1': 'Infineon',   '014F': 'Transcend',
    '017A': 'Apacer',    '0125': 'Kingmax',    '8502': 'Patriot',
    '01BA': 'PNY',
}

# Part number prefix -> manufacturer, used when the manufacturer code is empty
PART_NUMBER_VENDORS = [
    (r'^M[34][0-9]{2}[A-Z]', 'Samsung'),
    (r'^(HMT|HMA|HMC|HYMP)', 'SK Hynix'),
    (r'^MT[AC]?[0-9]', 'Micron'),
    (r'^(CT[0-9]|BLS?[0-9])', 'Crucial'),
    (r'^(KVR|KHX|KF[0-9]|KCP|KTD|KTH|KTL|KCM|ACR[0-9]|9905|99U5|HX[0-9])', 'Kingston'),
    (r'^CM[A-Z]', 'Corsair'),
    (r'^F[2-5]-', 'G.Skill'),
    (r'^(AD[2-5]|AX[2-5])', 'ADATA'),
    (r'^NT[0-9]', 'Nanya'),
    (r'^EB[EJ]', 'Elpida'),
    (r'^RM[ST]', 'Ramaxel'),
]

PLACEHOLDER = re.compile(
    r'^(0+|F+|Unknown|Undefined|Not ?Specified|Not Available|Manufacturer[0-9]*|To Be Filled.*)$',
    re.IGNORECASE)

# SMBIOS type 17, "Memory Type" field
SMBIOS_MEMORY_TYPES = {
    0x0F: 'SDRAM', 0x11: 'RDRAM', 0x12: 'DDR', 0x13: 'DDR2', 0x14: 'DDR2 FB-DIMM',
    0x18: 'DDR3', 0x19: 'FBD2', 0x1A: 'DDR4', 0x1B: 'LPDDR', 0x1C: 'LPDDR2',
    0x1D: 'LPDDR3', 0x1E: 'LPDDR4', 0x20: 'HBM', 0x21: 'HBM2', 0x22: 'DDR5',
    0x23: 'LPDDR5', 0x24: 'HBM3',
}

# ROM / Flash memory types (e.g. the BIOS "SYSTEM ROM"), which are not RAM modules
SMBIOS_ROM_TYPES = {0x08, 0x09, 0x0A, 0x0B, 0x0C}

# SMBIOS type 17, "Form Factor" field (Chip / Row of chips = soldered memory)
SMBIOS_FORM_FACTORS = {
    0x03: 'SIMM', 0x05: 'Soldered', 0x09: 'DIMM', 0x0B: 'Soldered',
    0x0C: 'RIMM', 0x0D: 'SO-DIMM', 0x0F: 'FB-DIMM',
}

COLUMNS = ['Slot', 'Brand', 'Part number', 'GB', 'Type', 'Form factor', 'Nominal MHz', 'Current MHz']
RIGHT_ALIGNED = {'GB', 'Nominal MHz', 'Current MHz'}


# --- Inference ----------------------------------------------------------------

def resolve_vendor(raw, part_number):
    m = (raw or '').strip()
    placeholder = not m or PLACEHOLDER.match(m)
    hex_code = None

    if not placeholder:
        upper = m.upper()
        found = re.search(r'0X([0-9A-F]{4})', upper)            # e.g. "Unknown - [0x9B85]" (HP BIOS)
        if found:
            hex_code = found.group(1)
        elif re.match(r'^[0-9A-F]{4,16}$', upper):
            hex_code = upper
        else:
            return m                                             # already a plain name

        candidates = [
            hex_code[0:4],                    # "80CE...": standard format
            hex_code[2:4] + hex_code[0:2],    # "9B85": swapped bytes
            '80' + hex_code[0:2],             # "CE00...": bank 1 without the bank byte
        ]
        for code in candidates:
            if code in JEDEC_VENDORS:
                return JEDEC_VENDORS[code]

    p = (part_number or '').strip().upper()
    if p:
        for pattern, vendor in PART_NUMBER_VENDORS:
            if re.match(pattern, p):
                return vendor + ' (estimated)'

    if hex_code:
        return 'JEDEC code ' + hex_code
    return 'Unknown'


def ddr_from_part_number(part_number):
    p = (part_number or '').strip().upper()
    if not p:
        return None

    found = re.search(r'LPDDR([2-5])', p)
    if found:
        return 'LPDDR' + found.group(1)
    for pattern in (r'DDR([2-5])', r'PC([2-5])L?-', r'^F([2-5])-'):  # PC3L-12800, G.Skill F4-...
        found = re.search(pattern, p)
        if found:
            return 'DDR' + found.group(1)

    rules = [
        (r'^HYMP', 'DDR2'), (r'^HMT', 'DDR3'), (r'^HMA', 'DDR4'), (r'^HMC', 'DDR5'),      # SK Hynix
        (r'^M[34][0-9]{2}T', 'DDR2'), (r'^M[34][0-9]{2}B', 'DDR3'),                      # Samsung
        (r'^M[34][0-9]{2}A', 'DDR4'), (r'^M[34][0-9]{2}R', 'DDR5'),
        (r'^MT[0-9]+H', 'DDR2'), (r'^MT[0-9]+[JK]', 'DDR3'),                             # Micron
        (r'^MTA', 'DDR4'), (r'^MTC', 'DDR5'),
        (r'^CT[0-9]+B[ADF][0-9]', 'DDR3'), (r'^CT[0-9]+G4[A-Z]', 'DDR4'),                # Crucial
        (r'^CT[0-9]+G[0-9]{2}C[0-9]{2}[SU]5', 'DDR5'),
        (r'^KVR(13|16|18)[A-Z]', 'DDR3'), (r'^KVR(21|24|26|29|32)[A-Z]', 'DDR4'),        # Kingston
        (r'^KVR(48|52|56|64)[A-Z]', 'DDR5'),
    ]
    for pattern, ddr in rules:
        if re.match(pattern, p):
            return ddr
    return None


def ddr_from_speed(mts):
    if not mts or mts <= 0:
        return None
    if mts < 200:
        return 'SDRAM'
    if mts <= 400:
        return 'DDR'
    if mts <= 667:
        return 'DDR2'
    if mts <= 1066:
        return 'DDR2 or DDR3'
    if mts <= 1866:
        return 'DDR3'
    if mts < 4800:
        return 'DDR4'
    return 'DDR5'


def resolve_type(exact, part_number, speed):
    if exact:
        return exact
    guess = ddr_from_part_number(part_number) or ddr_from_speed(speed)
    return guess + ' (estimated)' if guess else 'Unknown'


# --- SMBIOS table reading -----------------------------------------------------

def _u8(data, off):
    return data[off] if off < len(data) else None


def _u16(data, off):
    return struct.unpack_from('<H', data, off)[0] if off + 2 <= len(data) else None


def _u32(data, off):
    return struct.unpack_from('<I', data, off)[0] if off + 4 <= len(data) else None


def _u64(data, off):
    return struct.unpack_from('<Q', data, off)[0] if off + 8 <= len(data) else None


def parse_smbios(table):
    """Returns (system, memory arrays, modules) from the raw SMBIOS table."""
    system, arrays, modules = {}, [], []
    other_arrays = set()                                 # handles of non system-memory arrays (Flash...)
    i = 0
    while i + 4 <= len(table):
        stype, length = table[i], table[i + 1]
        if length < 4 or i + length > len(table):
            break
        end = table.find(b'\x00\x00', i + length)
        if end < 0:
            break
        fmt = table[i:i + length]
        raw_strings = table[i + length:end]
        strings = [s.decode('latin-1').strip() for s in raw_strings.split(b'\x00')] if raw_strings else []

        def string(off):
            idx = _u8(fmt, off)
            return strings[idx - 1] if idx and idx <= len(strings) else ''

        if stype == 1:                                   # System Information
            system = {'manufacturer': string(0x04), 'model': string(0x05)}

        elif stype == 16:                                # Physical Memory Array
            if _u8(fmt, 0x05) != 0x03:                   # usage other than "system memory"
                other_arrays.add(_u16(fmt, 0x02))
            else:
                max_kb = _u32(fmt, 0x07)
                if max_kb == 0x80000000:
                    max_bytes = _u64(fmt, 0x0F) or 0
                else:
                    max_bytes = (max_kb or 0) * 1024
                arrays.append({'slots': _u16(fmt, 0x0D) or 0, 'max_bytes': max_bytes})

        elif stype == 17:                                # Memory Device
            size = _u16(fmt, 0x0C)
            memory_type = _u8(fmt, 0x12)
            if size and memory_type not in SMBIOS_ROM_TYPES:   # 0 = empty slot
                if size == 0xFFFF:
                    size_mb = None                       # unknown size
                elif size == 0x7FFF:
                    size_mb = (_u32(fmt, 0x1C) or 0) & 0x7FFFFFFF
                elif size & 0x8000:
                    size_mb = (size & 0x7FFF) / 1024.0   # size in KB
                else:
                    size_mb = size

                speed = _u16(fmt, 0x15)
                if speed == 0xFFFF:
                    speed = _u32(fmt, 0x54)
                configured = _u16(fmt, 0x20)
                if configured == 0xFFFF:
                    configured = _u32(fmt, 0x58)

                modules.append({
                    'array': _u16(fmt, 0x04),
                    'slot': string(0x10) or string(0x11),
                    'vendor': string(0x17),
                    'part': string(0x1A),
                    'size_mb': size_mb,
                    'type': SMBIOS_MEMORY_TYPES.get(memory_type),
                    'form': SMBIOS_FORM_FACTORS.get(_u8(fmt, 0x0E), ''),
                    'speed': speed or 0,
                    'configured': configured or 0,
                })

        elif stype == 127:                               # end of table
            break
        i = end + 2

    # Arrays may come after their devices: filter once the whole table is read
    modules = [m for m in modules if m['array'] not in other_arrays]
    return system, arrays, modules


def table_from_dump(data):
    """Accepts a raw table or a "dmidecode --dump-bin" file (entry point + table)."""
    if data.startswith(b'_SM3_'):
        return data[_u64(data, 0x10):]
    if data.startswith(b'_SM_'):
        return data[_u32(data, 0x18):]
    if data.startswith(b'_DMI_'):
        return data[_u32(data, 0x08):]
    return data


def read_smbios_windows():
    import ctypes
    kernel32 = ctypes.windll.kernel32
    kernel32.GetSystemFirmwareTable.restype = ctypes.c_uint
    kernel32.GetSystemFirmwareTable.argtypes = [ctypes.c_uint, ctypes.c_uint, ctypes.c_void_p, ctypes.c_uint]
    rsmb = 0x52534D42                                    # 'RSMB': raw SMBIOS table
    size = kernel32.GetSystemFirmwareTable(rsmb, 0, None, 0)
    if not size:
        raise OSError('GetSystemFirmwareTable failed')
    buf = ctypes.create_string_buffer(size)
    size = kernel32.GetSystemFirmwareTable(rsmb, 0, buf, size)
    data = buf.raw[:size]
    length = struct.unpack_from('<I', data, 4)[0]        # 8-byte RawSMBIOSData header
    return data[8:8 + length]


def read_smbios_linux():
    path = '/sys/firmware/dmi/tables/DMI'
    try:
        with open(path, 'rb') as f:
            return f.read()
    except PermissionError:
        sys.exit('The SMBIOS table is only readable by root: run again with sudo.')
    except FileNotFoundError:
        sys.exit('%s not found (kernel older than 4.2, or a machine without SMBIOS such as a Raspberry Pi).' % path)


# --- macOS --------------------------------------------------------------------

def _parse_size_mb(text):
    # Units may be localized (Go, Mo... on a French macOS)
    found = re.match(r'^\s*([0-9.]+)\s*([KMGT])[BO]', text or '', re.IGNORECASE)
    if not found:
        return None
    factor = {'K': 1.0 / 1024, 'M': 1, 'G': 1024, 'T': 1024 * 1024}[found.group(2).upper()]
    return float(found.group(1)) * factor


def _decode_hex_string(text):
    """Intel Macs report the part number hex-encoded (0x4D3437...)."""
    text = (text or '').strip()
    if re.match(r'^0x([0-9A-Fa-f]{2}){4,}$', text):
        try:
            return bytes.fromhex(text[2:]).decode('ascii', 'replace').strip(' \x00')
        except ValueError:
            pass
    return text


def read_macos():
    data = plistlib.loads(subprocess.check_output(['system_profiler', '-xml', 'SPMemoryDataType']))
    modules = []

    def walk(node):
        if isinstance(node, list):
            for item in node:
                walk(item)
        elif isinstance(node, dict):
            if 'dimm_type' in node or 'dimm_size' in node:
                size_mb = _parse_size_mb(node.get('dimm_size') or node.get('SPMemoryDataType'))
                if size_mb:
                    speed = re.match(r'^\s*([0-9]+)', node.get('dimm_speed', '') or '')
                    modules.append({
                        'slot': node.get('_name', '') if 'dimm_size' in node else 'Built-in',  # Apple Silicon
                        'vendor': node.get('dimm_manufacturer', ''),
                        'part': _decode_hex_string(node.get('dimm_part_number', '')),
                        'size_mb': size_mb,
                        'type': node.get('dimm_type') or None,
                        'form': '' if 'dimm_size' in node else 'Soldered',
                        'speed': int(speed.group(1)) if speed else 0,
                        'configured': 0,
                    })
                return
            for value in node.values():
                walk(value)

    walk(data)
    try:
        model = subprocess.check_output(['sysctl', '-n', 'hw.model']).decode().strip()
    except (OSError, subprocess.CalledProcessError):
        model = ''
    return {'manufacturer': 'Apple', 'model': model}, [], modules


# --- Output -------------------------------------------------------------------

def format_gb(size_mb):
    if size_mb is None:
        return '?'
    return '%g' % round(size_mb / 1024.0, 1)


def build_rows(modules):
    rows = []
    for m in modules:
        rows.append({
            'Slot': m['slot'],
            'Brand': resolve_vendor(m['vendor'], m['part']),
            'Part number': m['part'],
            'GB': format_gb(m['size_mb']),
            'Type': resolve_type(m['type'], m['part'], m['speed']),
            'Form factor': m['form'],
            'Nominal MHz': str(m['speed']) if m['speed'] else '?',
            'Current MHz': str(m['configured']) if m['configured'] else '?',
        })
    return rows


def print_table(rows):
    widths = {c: max([len(c)] + [len(r[c]) for r in rows]) for c in COLUMNS}

    def line(values):
        cells = []
        for c in COLUMNS:
            cells.append(values[c].rjust(widths[c]) if c in RIGHT_ALIGNED else values[c].ljust(widths[c]))
        return ' '.join(cells).rstrip()

    print(line({c: c for c in COLUMNS}))
    print(line({c: '-' * len(c) for c in COLUMNS}))
    for r in rows:
        print(line(r))


def make_stdout_safe():
    """Never crash on a character the console cannot display (e.g. non UTF-8 locale)."""
    if hasattr(sys.stdout, 'reconfigure'):               # Python 3.7+
        sys.stdout.reconfigure(errors='replace')
    elif hasattr(sys.stdout, 'buffer'):                  # Python 3.6
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding=sys.stdout.encoding,
                                      errors='replace', line_buffering=True)


def main():
    parser = argparse.ArgumentParser(description='Lists the installed RAM modules.')
    parser.add_argument('--csv', metavar='FILE', help='also export the result as CSV (";" separator)')
    parser.add_argument('--dmi-file', metavar='FILE',
                        help='parse a saved SMBIOS table (copy of /sys/firmware/dmi/tables/DMI '
                             'or "dmidecode --dump-bin" output)')
    args = parser.parse_args()
    make_stdout_safe()

    if args.dmi_file:
        with open(args.dmi_file, 'rb') as f:
            system, arrays, modules = parse_smbios(table_from_dump(f.read()))
    elif sys.platform == 'win32':
        system, arrays, modules = parse_smbios(read_smbios_windows())
    elif sys.platform == 'darwin':
        system, arrays, modules = read_macos()
    else:
        system, arrays, modules = parse_smbios(read_smbios_linux())

    print()
    print('PC: %s %s (%s)' % (system.get('manufacturer', ''), system.get('model', ''), platform.node()))

    if not modules:
        print('No RAM module found (virtual machine?).')
        return

    rows = build_rows(modules)
    print_table(rows)
    print()

    total_mb = sum(m['size_mb'] or 0 for m in modules)
    summary = 'Total: %s GB in %d module(s)' % (format_gb(total_mb), len(modules))
    slots = sum(a['slots'] for a in arrays)
    if slots:
        summary += ' - %d/%d slot(s) used' % (len(modules), slots)
    max_bytes = sum(a['max_bytes'] for a in arrays)
    if max_bytes:
        summary += ' - BIOS official max: %g GB' % round(max_bytes / 1024.0 ** 3)
    print(summary)
    print()

    if args.csv:
        with open(args.csv, 'w', newline='', encoding='utf-8-sig') as f:   # BOM for Excel
            writer = csv.DictWriter(f, fieldnames=COLUMNS, delimiter=';')
            writer.writeheader()
            writer.writerows(rows)
        print('Exported to ' + args.csv)


if __name__ == '__main__':
    main()
