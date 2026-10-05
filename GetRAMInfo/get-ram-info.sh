#!/usr/bin/env bash
# Lists the installed RAM modules: slot, brand, part number, size,
# DDR type and frequency.
#
#   - Linux   : dmidecode (requires root: sudo)
#   - macOS   : system_profiler
#   - Windows : Git Bash, MSYS2, Cygwin or WSL, through powershell.exe (WMI)
#
# When a value is missing, it is inferred from the module's part number
# (or its speed) and followed by "(estimated)".
# "MHz" is the marketing figure (actually MT/s); the real bus clock is half
# of it.
#
# Virtual machines (VirtualBox, VMware, Hyper-V, QEMU/KVM, Xen, Parallels...)
# are recognized from the system manufacturer and model, or from the "virtual
# machine" flag of the firmware. Their memory modules are emulated: their type
# is shown as "Virtual" instead of being estimated, and the RAM allocated to
# the VM, as seen by the OS, is shown as well (some hypervisors, VirtualBox by
# default, expose no module at all).
#
# Compatible with bash 3.2 (macOS) and later, and with any awk
# (gawk, mawk, BWK awk, busybox).

usage() {
    cat <<'EOF'
Usage: get-ram-info.sh [-c file.csv] [-f dmidecode_output.txt]

  -c FILE   also export the result as CSV (";" separator)
  -f FILE   parse a saved dmidecode output
            (e.g. "sudo dmidecode > dmidecode.txt" on another machine)
  -h        show this help

On Linux, run with sudo (dmidecode reads the firmware SMBIOS table).
EOF
}

die() { echo "$*" >&2; exit 1; }

csv_file=''
input_file=''
while getopts 'c:f:h' opt; do
    case "$opt" in
        c) csv_file=$OPTARG ;;
        f) input_file=$OPTARG ;;
        h) usage; exit 0 ;;
        *) usage >&2; exit 1 ;;
    esac
done

# Column widths are computed in characters: a UTF-8 locale is required
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
    *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) ;;
    *) if locale -a 2>/dev/null | grep -qi '^c\.utf-\{0,1\}8$'; then export LC_ALL=C.UTF-8; fi ;;
esac

# --- Collection ----------------------------------------------------------------
# Every source prints lines in a common format:
#   S|PC manufacturer|model
#   V|1 if the firmware flags a virtual machine
#   T|RAM visible to the OS (MB)
#   A|number of slots|max capacity (MB)
#   M|slot|manufacturer|part number|size (MB, or ? if unknown)|type|form factor|nominal MHz|current MHz

parse_dmidecode() {
    awk '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); gsub(/\|/, "/", s); return s }
    function to_mb(v,   n, u) {
        n = v + 0; if (n <= 0) return 0
        u = v; sub(/^[0-9.]+ */, "", u)
        if (u ~ /^[kK]B/) return n / 1024
        if (u ~ /^MB/) return n
        if (u ~ /^GB/) return n * 1024
        if (u ~ /^TB/) return n * 1048576
        return 0
    }
    function flush() {
        # ROM / Flash devices (e.g. the BIOS "SYSTEM ROM") are not RAM modules
        if (sec == "mem" && (size_mb == "?" || size_mb + 0 > 0) && type !~ /^(Flash|ROM|EEPROM|EPROM|FEPROM)$/) {
            n++
            dev_array[n] = array
            dev_line[n] = "M|" (loc != "" ? loc : bank) "|" mfr "|" part "|" size_mb "|" type "|" form "|" speed "|" conf
        } else if (sec == "arr") {
            if (use == "System Memory") print "A|" devices "|" maxcap
            else other_array[handle] = 1
        } else if (sec == "sys")
            print "S|" sman "|" sprod
        sec = ""
    }
    { sub(/\r$/, "") }
    /^\t\tSystem is a virtual machine$/ { print "V|1"; next }    # BIOS Information characteristic
    /^Handle /                { flush(); handle = $2; sub(/,$/, "", handle); next }
    /^System Information$/    { flush(); sec = "sys"; sman = sprod = ""; next }
    /^Physical Memory Array$/ { flush(); sec = "arr"; use = ""; devices = 0; maxcap = 0; next }
    /^Memory Device$/         { flush(); sec = "mem"; loc = bank = mfr = part = type = form = array = ""; size_mb = speed = conf = 0; next }
    sec != "" && /^\t[^\t]/ {
        line = $0; sub(/^\t/, "", line)
        k = line; sub(/:.*/, "", k)
        v = ""; if (index(line, ":")) { v = line; sub(/^[^:]*:/, "", v) }
        v = trim(v)
        if (sec == "sys") {
            if (k == "Manufacturer") sman = v
            else if (k == "Product Name") sprod = v
        } else if (sec == "arr") {
            if (k == "Use") use = v
            else if (k == "Number Of Devices") devices = v + 0
            else if (k == "Maximum Capacity") maxcap = to_mb(v)
        } else {
            if (k == "Size") size_mb = (v == "Unknown") ? "?" : to_mb(v)
            else if (k == "Array Handle") array = v
            else if (k == "Form Factor") form = v
            else if (k == "Locator") loc = v
            else if (k == "Bank Locator") bank = v
            else if (k == "Type") type = v
            else if (k == "Speed") speed = v + 0
            else if (k == "Manufacturer") mfr = v
            else if (k == "Part Number") part = v
            else if (k == "Configured Memory Speed" || k == "Configured Clock Speed") conf = v + 0
        }
    }
    END {
        flush()
        # Arrays may come after their devices: filter once the whole output is read
        for (i = 1; i <= n; i++) if (!(dev_array[i] in other_array)) print dev_line[i]
    }'
}

collect_linux() {
    if [ -n "$input_file" ]; then
        [ -r "$input_file" ] || die "Cannot read file: $input_file"
        parse_dmidecode < "$input_file"
        return
    fi
    command -v dmidecode >/dev/null 2>&1 || die "dmidecode not found: install it (e.g. sudo apt install dmidecode)."
    [ "$(id -u)" -eq 0 ] || die "dmidecode reads the firmware SMBIOS table: run again with sudo."
    awk '/^MemTotal:/ { printf "T|%d\n", $2 / 1024 }' /proc/meminfo
    dmidecode -t 0,1,16,17 | parse_dmidecode
}

collect_macos() {
    echo "S|Apple|$(sysctl -n hw.model 2>/dev/null)"
    echo "V|$(sysctl -n kern.hv_vmm_present 2>/dev/null)"
    sysctl -n hw.memsize 2>/dev/null | awk '{ printf "T|%d\n", $1 / 1048576 }'
    # XML output: its keys (dimm_size...) are not translated, unlike the text output
    system_profiler -xml SPMemoryDataType | awk '
    function to_mb(v,   n, u) {
        n = v + 0; if (n <= 0) return 0
        u = v; sub(/^[0-9.]+ */, "", u)
        if (u ~ /^[Mm][BbOo]/) return n
        if (u ~ /^[Gg][BbOo]/) return n * 1024
        if (u ~ /^[Tt][BbOo]/) return n * 1048576
        return 0
    }
    function reset() { name = size = mfr = part = type = speed = ""; dimm = slotted = 0 }
    function xml_text(s) {
        sub(/^[^>]*>/, "", s); sub(/<.*/, "", s)
        gsub(/&lt;/, "<", s); gsub(/&gt;/, ">", s); gsub(/&amp;/, "\\&", s); gsub(/\|/, "/", s)
        return s
    }
    BEGIN { reset() }
    /<dict>/   { reset() }
    /<\/dict>/ {
        if (dimm && to_mb(size) > 0) {
            # Intel Macs have slots (dimm_size); Apple Silicon has a single soldered entry
            print "M|" (slotted ? name : "Built-in") "|" mfr "|" part "|" to_mb(size) "|" type "|" (slotted ? "" : "Soldered") "|" (speed + 0) "|0"
        }
        reset()
    }
    /<key>/    { key = $0; sub(/.*<key>/, "", key); sub(/<\/key>.*/, "", key) }
    /<string>/ {
        v = $0; sub(/.*<string>/, "<string>", v); v = xml_text(v)
        if (key == "_name") name = v
        else if (key == "dimm_size") { size = v; dimm = slotted = 1 }
        else if (key == "SPMemoryDataType") size = v
        else if (key == "dimm_type") { type = v; dimm = 1 }
        else if (key == "dimm_speed") speed = v
        else if (key == "dimm_manufacturer") mfr = v
        else if (key == "dimm_part_number") part = v
        key = ""
    }'
}

collect_windows() {
    # PowerShell 2.0 compatible script (Windows 7), passed encoded to avoid quoting issues
    local ps='
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"
$cs = Get-WmiObject Win32_ComputerSystem
"S|" + "$($cs.Manufacturer)".Trim() + "|" + "$($cs.Model)".Trim()
"T|" + [math]::Round([double]$cs.TotalPhysicalMemory / 1MB)
Get-WmiObject Win32_PhysicalMemoryArray | Where-Object { $_.Use -eq 3 } | ForEach-Object {
    $max = [double]$_.MaxCapacityEx
    if ($max -le 0) { $max = [double]$_.MaxCapacity }
    "A|" + $_.MemoryDevices + "|" + [math]::Round($max / 1024)
}
$smbios = @{ 15="SDRAM"; 17="RDRAM"; 18="DDR"; 19="DDR2"; 20="DDR2 FB-DIMM"; 24="DDR3"; 25="FBD2"; 26="DDR4"; 27="LPDDR"; 28="LPDDR2"; 29="LPDDR3"; 30="LPDDR4"; 32="HBM"; 33="HBM2"; 34="DDR5"; 35="LPDDR5"; 36="HBM3" }
$cim = @{ 17="SDRAM"; 19="RDRAM"; 20="DDR"; 21="DDR2"; 22="DDR2 FB-DIMM"; 24="DDR3"; 25="FBD2"; 26="DDR4" }
$smbiosRom = @(8, 9, 10, 11, 12)
$cimRom = @(10, 11, 12, 13, 14)
$ff = @{ 7="SIMM"; 8="DIMM"; 11="RIMM"; 12="SO-DIMM" }
Get-WmiObject Win32_PhysicalMemory | ForEach-Object {
    if (($_.SMBIOSMemoryType -and ($smbiosRom -contains [int]$_.SMBIOSMemoryType)) -or ($_.MemoryType -and ($cimRom -contains [int]$_.MemoryType))) { return }
    $type = ""
    if ($_.SMBIOSMemoryType -and $smbios.ContainsKey([int]$_.SMBIOSMemoryType)) { $type = $smbios[[int]$_.SMBIOSMemoryType] }
    elseif ($_.MemoryType -and $cim.ContainsKey([int]$_.MemoryType)) { $type = $cim[[int]$_.MemoryType] }
    $form = ""
    if ($_.FormFactor -and $ff.ContainsKey([int]$_.FormFactor)) { $form = $ff[[int]$_.FormFactor] }
    $slot = "$($_.DeviceLocator)".Trim()
    if (-not $slot) { $slot = "$($_.BankLabel)".Trim() }
    $size = "?"
    if ([double]$_.Capacity -gt 0) { $size = [math]::Round([double]$_.Capacity / 1MB) }
    $f = @("M", $slot, "$($_.Manufacturer)".Trim(), "$($_.PartNumber)".Trim(), $size, $type, $form, [int]$_.Speed, [int]$_.ConfiguredClockSpeed)
    ($f | ForEach-Object { "$_" -replace "\|", "/" }) -join "|"
}'
    # -EncodedCommand expects base64 UTF-16LE. The script being ASCII, appending a
    # null byte after each byte is enough (iconv is missing from some Git Bash installs).
    local esc encoded
    esc=$(printf '%s' "$ps" | od -An -v -tx1 | tr -s ' \n' '\n' | sed -n 's/^\([0-9a-f][0-9a-f]\)$/\\x\1\\x00/p' | tr -d '\n')
    encoded=$(printf "$esc" | base64 | tr -d '\n')
    [ -n "$encoded" ] || die "Cannot encode the PowerShell script (od or base64 missing)."
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
        powershell.exe -NoProfile -NonInteractive -EncodedCommand "$encoded" | tr -d '\r'
}

# --- Inference -----------------------------------------------------------------

upper() { printf '%s' "$1" | tr '[:lower:]' '[:upper:]'; }

# JEDEC manufacturer codes as the firmware reports them (bank byte + identifier)
jedec_vendor() {
    case "$1" in
        80CE) echo 'Samsung' ;;   80AD) echo 'SK Hynix' ;;   802C) echo 'Micron' ;;
        859B) echo 'Crucial' ;;   0198) echo 'Kingston' ;;   029E) echo 'Corsair' ;;
        04CD) echo 'G.Skill' ;;   04EF) echo 'Team Group' ;; 04CB) echo 'ADATA' ;;
        0443) echo 'Ramaxel' ;;   830B) echo 'Nanya' ;;      80FE) echo 'Elpida' ;;
        8551) echo 'Qimonda' ;;   80C1) echo 'Infineon' ;;   014F) echo 'Transcend' ;;
        017A) echo 'Apacer' ;;    0125) echo 'Kingmax' ;;    8502) echo 'Patriot' ;;
        01BA) echo 'PNY' ;;
        *) return 1 ;;
    esac
}

# Applies a list of "regex=result" rules to $1 and prints the first matching result
first_match() {
    local value="$1" rule re
    while IFS= read -r rule; do
        [ -n "$rule" ] || continue
        re=${rule%=*}
        if [[ $value =~ $re ]]; then echo "${rule##*=}"; return 0; fi
    done <<< "$2"
    return 1
}

# Part number prefix -> manufacturer, used when the manufacturer code is empty
PART_VENDORS='^M[34][0-9]{2}[A-Z]=Samsung
^(HMT|HMA|HMC|HYMP)=SK Hynix
^MT[AC]?[0-9]=Micron
^(CT[0-9]|BLS?[0-9])=Crucial
^(KVR|KHX|KF[0-9]|KCP|KTD|KTH|KTL|KCM|ACR[0-9]|9905|99U5|HX[0-9])=Kingston
^CM[A-Z]=Corsair
^F[2-5]-=G.Skill
^(AD[2-5]|AX[2-5])=ADATA
^NT[0-9]=Nanya
^EB[EJ]=Elpida
^RM[ST]=Ramaxel'

# Part numbers whose DDR type is known (SK Hynix, Samsung, Micron, Crucial, Kingston)
PART_DDR='^HYMP=DDR2
^HMT=DDR3
^HMA=DDR4
^HMC=DDR5
^M[34][0-9]{2}T=DDR2
^M[34][0-9]{2}B=DDR3
^M[34][0-9]{2}A=DDR4
^M[34][0-9]{2}R=DDR5
^MT[0-9]+H=DDR2
^MT[0-9]+[JK]=DDR3
^MTA=DDR4
^MTC=DDR5
^CT[0-9]+B[ADF][0-9]=DDR3
^CT[0-9]+G4[A-Z]=DDR4
^CT[0-9]+G[0-9]{2}C[0-9]{2}[SU]5=DDR5
^KVR(13|16|18)[A-Z]=DDR3
^KVR(21|24|26|29|32)[A-Z]=DDR4
^KVR(48|52|56|64)[A-Z]=DDR5'

# "manufacturer model" of the system, in lower case -> hypervisor
HYPERVISORS='virtualbox|innotek=VirtualBox
vmware=VMware
microsoft corporation virtual machine=Hyper-V
parallels=Parallels
qemu|bochs|standard pc \(|openstack|ovirt|rhev|proxmox|(^| )kvm( |$)=QEMU/KVM
(^| )xen( |$)|hvm domu=Xen
virtualmac|apple virtualization=Apple Virtualization
bhyve=bhyve
amazon ec2=Amazon EC2
google compute engine=Google Compute Engine'

# Prints the hypervisor name, "Unknown" if only the firmware flags a virtual
# machine, nothing on a physical machine
detect_hypervisor() {
    local system
    system=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    first_match "$system" "$HYPERVISORS" || { [ "$2" = 1 ] && echo 'Unknown'; }
}

resolve_vendor() {
    local m="$1" part="$2" up hex='' code vendor
    local re_placeholder='^(0+|F+|UNKNOWN|UNDEFINED|NOT ?SPECIFIED|NOT AVAILABLE|MANUFACTURER[0-9]*|TO BE FILLED.*)$'
    local re_0x='0X([0-9A-F]{4})' re_hex='^[0-9A-F]{4,16}$'
    up=$(upper "$m")

    if [ -n "$m" ] && ! [[ $up =~ $re_placeholder ]]; then
        if [[ $up =~ $re_0x ]]; then hex=${BASH_REMATCH[1]}          # e.g. "Unknown - [0x9B85]" (HP BIOS)
        elif [[ $up =~ $re_hex ]]; then hex=$up
        else echo "$m"; return; fi                                  # already a plain name
        # standard format "80CE...", swapped bytes "9B85", bank 1 without the bank byte "CE00..."
        for code in "${hex:0:4}" "${hex:2:2}${hex:0:2}" "80${hex:0:2}"; do
            jedec_vendor "$code" && return
        done
    fi

    if [ -n "$part" ] && vendor=$(first_match "$(upper "$part")" "$PART_VENDORS"); then
        echo "$vendor (estimated)"
    elif [ -n "$hex" ]; then
        echo "JEDEC code $hex"
    else
        echo 'Unknown'
    fi
}

ddr_from_part() {
    local p re
    p=$(upper "$1")
    [ -n "$p" ] || return 1
    re='LPDDR([2-5])';  if [[ $p =~ $re ]]; then echo "LPDDR${BASH_REMATCH[1]}"; return 0; fi
    re='DDR([2-5])';    if [[ $p =~ $re ]]; then echo "DDR${BASH_REMATCH[1]}"; return 0; fi
    re='PC([2-5])L?-';  if [[ $p =~ $re ]]; then echo "DDR${BASH_REMATCH[1]}"; return 0; fi   # PC3L-12800
    re='^F([2-5])-';    if [[ $p =~ $re ]]; then echo "DDR${BASH_REMATCH[1]}"; return 0; fi   # G.Skill
    first_match "$p" "$PART_DDR"
}

ddr_from_speed() {
    local s=$1
    if   [ "$s" -le 0 ];    then return 1
    elif [ "$s" -lt 200 ];  then echo 'SDRAM'
    elif [ "$s" -le 400 ];  then echo 'DDR'
    elif [ "$s" -le 667 ];  then echo 'DDR2'
    elif [ "$s" -le 1066 ]; then echo 'DDR2 or DDR3'
    elif [ "$s" -le 1866 ]; then echo 'DDR3'
    elif [ "$s" -lt 4800 ]; then echo 'DDR4'
    else echo 'DDR5'
    fi
}

resolve_type() {
    local exact="$1" part="$2" speed="$3" virtual="$4" guess re='(DDR|SDRAM|RDRAM|HBM|FBD)'
    if [[ $exact =~ $re ]]; then echo "$exact"; return; fi
    if [ -n "$virtual" ]; then echo 'Virtual'; return; fi    # emulated module: an estimated DDR type would be misleading
    if guess=$(ddr_from_part "$part") || guess=$(ddr_from_speed "$speed"); then
        echo "$guess (estimated)"
    else
        echo 'Unknown'
    fi
}

normalize_form() {
    case "$1" in
        SODIMM|SO-DIMM)       echo 'SO-DIMM' ;;
        'Row Of Chips'|Chip)  echo 'Soldered' ;;
        DIMM|SIMM|RIMM|FB-DIMM|Soldered) echo "$1" ;;
        *) echo '' ;;
    esac
}

# Intel Macs report the part number hex-encoded (0x4D3437...)
decode_hex() {
    local s="$1" re='^0x([0-9A-Fa-f][0-9A-Fa-f]){4,}$' hex esc=''
    if [[ $s =~ $re ]]; then
        hex=${s#0x}
        while [ -n "$hex" ]; do esc="$esc\\x${hex:0:2}"; hex=${hex:2}; done
        printf "$esc" | tr -d '\000' | sed 's/ *$//'
    else
        echo "$s"
    fi
}

mb_to_gb() {
    case "$1" in
        ''|'?') echo '?' ;;                                  # size not reported by the firmware
        *) awk -v m="$1" 'BEGIN { printf "%g", int(m / 1024 * 10 + 0.5) / 10 }' ;;
    esac
}

# --- Main ----------------------------------------------------------------------

if [ -n "$input_file" ]; then
    os=linux
else
    case "$(uname -s)" in
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null && command -v powershell.exe >/dev/null 2>&1; then
                os=windows      # WSL: the real RAM is the Windows host's
            else
                os=linux
            fi ;;
        Darwin) os=macos ;;
        MINGW*|MSYS*|CYGWIN*) os=windows ;;
        *) die "Unsupported system: $(uname -s)" ;;
    esac
fi

data=$(collect_$os) || exit 1
[ -n "$data" ] || die "Cannot read the memory information."

pc_vendor='' pc_model='' vm_flag='' os_mb=0 slots=0 max_mb=0 total_mb=0 count=0
MODULES=()
while IFS='|' read -r kind f1 f2 f3 f4 f5 f6 f7 f8; do
    case "$kind" in
        S) pc_vendor=$f1 pc_model=$f2 ;;
        V) vm_flag=$f1 ;;
        T) os_mb=$f1 ;;
        A) slots=$((slots + ${f1:-0}))
           max_mb=$(awk -v a="$max_mb" -v b="${f2:-0}" 'BEGIN { print a + b }') ;;
        M) MODULES[${#MODULES[@]}]="$f1|$f2|$f3|$f4|$f5|$f6|$f7|$f8" ;;
    esac
done <<< "$data"

# Read once the whole data is parsed: the module columns depend on it
hypervisor=$(detect_hypervisor "$pc_vendor $pc_model" "$vm_flag")

ROWS=()
for module in "${MODULES[@]}"; do
    # f1 slot, f2 manufacturer, f3 part number, f4 size MB, f5 type, f6 form factor, f7 MHz, f8 current MHz
    IFS='|' read -r f1 f2 f3 f4 f5 f6 f7 f8 <<< "$module"
    f3=$(decode_hex "$f3")
    speed=${f7:-0}; conf=${f8:-0}
    [ "$speed" -gt 0 ] 2>/dev/null || speed=0
    [ "$conf" -gt 0 ] 2>/dev/null || conf=0
    brand=$(resolve_vendor "$f2" "$f3")
    [ -n "$hypervisor" ] && [ "$brand" = 'Unknown' ] && brand=$hypervisor
    ROWS[count]="$f1|$brand|$f3|$(mb_to_gb "$f4")|$(resolve_type "$f5" "$f3" "$speed" "$hypervisor")|$(normalize_form "$f6")|${speed/#0/?}|${conf/#0/?}"
    total_mb=$(awk -v a="$total_mb" -v b="$f4" 'BEGIN { print a + b }')
    count=$((count + 1))
done

os_ram=''
[ "$os_mb" -gt 0 ] 2>/dev/null && os_ram="RAM visible to the OS: $(mb_to_gb "$os_mb") GB"

echo
if [ -n "$hypervisor" ]; then
    echo "VM: $pc_vendor $pc_model (${HOSTNAME:-$(hostname)}) - hypervisor: $hypervisor"
else
    echo "PC: $pc_vendor $pc_model (${HOSTNAME:-$(hostname)})"
fi

if [ "$count" -eq 0 ]; then
    if [ -n "$hypervisor" ]; then
        echo 'No memory module exposed by the hypervisor.'
    else
        echo 'No RAM module found (virtual machine?).'
    fi
    [ -n "$os_ram" ] && echo "$os_ram"
    echo
    exit 0
fi

HEADERS=('Slot' 'Brand' 'Part number' 'GB' 'Type' 'Form factor' 'Nominal MHz' 'Current MHz')
RIGHT=' 3 6 7 '      # right-aligned columns (GB, MHz)

WIDTHS=()
for i in 0 1 2 3 4 5 6 7; do WIDTHS[i]=${#HEADERS[i]}; done
for row in "${ROWS[@]}"; do
    IFS='|' read -r -a f <<< "$row"
    for i in 0 1 2 3 4 5 6 7; do
        cell=${f[i]:-}
        [ ${#cell} -gt "${WIDTHS[i]}" ] && WIDTHS[i]=${#cell}
    done
done

print_row() {   # cells separated by |
    local line='' i cell pad
    IFS='|' read -r -a f <<< "$1"
    for i in 0 1 2 3 4 5 6 7; do
        cell=${f[i]:-}
        pad=$(( WIDTHS[i] - ${#cell} ))
        case "$RIGHT" in
            *" $i "*) line="$line$(printf '%*s' "$pad" '')$cell " ;;
            *)        line="$line$cell$(printf '%*s' "$pad" '') " ;;
        esac
    done
    echo "${line%"${line##*[! ]}"}"     # without trailing spaces
}

header_line=$(IFS='|'; echo "${HEADERS[*]}")
print_row "$header_line"
print_row "$(echo "$header_line" | sed 's/[^|]/-/g')"
for row in "${ROWS[@]}"; do print_row "$row"; done
echo

if [ -n "$hypervisor" ]; then
    # The slot count and maximum capacity of a virtual firmware are meaningless
    summary="Total: $(mb_to_gb "$total_mb") GB in $count virtual module(s)"
    [ -n "$os_ram" ] && summary="$summary - $os_ram"
else
    summary="Total: $(mb_to_gb "$total_mb") GB in $count module(s)"
    [ "$slots" -gt 0 ] && summary="$summary - $count/$slots slot(s) used"
    max_gb=$(awk -v m="$max_mb" 'BEGIN { printf "%d", m / 1024 + 0.5 }')
    [ "$max_gb" -gt 0 ] && summary="$summary - BIOS official max: $max_gb GB"
fi
echo "$summary"
echo

if [ -n "$csv_file" ]; then
    {
        printf '\357\273\277'                     # UTF-8 BOM for Excel
        for row in "$header_line" "${ROWS[@]}"; do
            IFS='|' read -r -a f <<< "$row"
            out=''
            for i in 0 1 2 3 4 5 6 7; do
                cell=${f[i]:-}
                out="$out\"${cell//\"/\"\"}\";"
            done
            echo "${out%;}"
        done
    } > "$csv_file" || die "Cannot write: $csv_file"
    echo "Exported to $csv_file"
fi
