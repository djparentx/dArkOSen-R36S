#!/usr/bin/env bash
# dtb-verify-60hz.sh  (no args; scans the folder this script is in)
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v dtc >/dev/null || { echo "dtc missing: sudo apt install device-tree-compiler"; exit 1; }
log="$root/dtb-verify-60hz.log"
tmp="$(mktemp)"

while IFS= read -r -d '' f; do
  rel="${f#"$root"/}"
  dtc -I dtb -O dts -q "$f" 2>/dev/null | awk -v n="$rel" '
    function hx(s,  i,d,v){ s=tolower(s); gsub(/[<>;]|0x/,"",s); v=0
      for(i=1;i<=length(s);i++){ d=index("0123456789abcdef",substr(s,i,1))-1; v=v*16+d } return v }
    function ind(l){ match(l,/^\t*/); return RLENGTH }
    /display-timings \{/ { on=1; base=ind($0); found=1; next }
    on && ind($0)==base && /^\t*\};/ { on=0; next }
    on && ind($0)==base+1 && /native-mode/ { nat=hx($3); next }
    on && ind($0)==base+1 && /\{$/ { name=$1; cf=ha=hf=hs=hb=va=vf=vs=vb=ph=0; next }
    on && /clock-frequency/ { cf=hx($3) }
    on && /hactive/        { ha=hx($3) }
    on && /hfront-porch/   { hf=hx($3) }
    on && /hsync-len/      { hs=hx($3) }
    on && /hback-porch/    { hb=hx($3) }
    on && /vactive/        { va=hx($3) }
    on && /vfront-porch/   { vf=hx($3) }
    on && /vsync-len/      { vs=hx($3) }
    on && /vback-porch/    { vb=hx($3) }
    on && /phandle/        { ph=hx($3) }
    on && ind($0)==base+1 && /^\t*\};/ {
      k++; nm[k]=name; ph_[k]=ph; w[k]=ha; h[k]=va; c[k]=cf
      ht[k]=ha+hf+hs+hb; vt[k]=va+vf+vs+vb
      hz[k]=(ht[k]*vt[k]>0)? cf/(ht[k]*vt[k]) : 0
      all=all (all==""?"":", ") sprintf("%s %.2f", name, hz[k])
    }
    END {
      if (!found) { printf "0\tNO-TIMINGS\t-\t-\t-\t-\t-\t%s\t-\n", n; exit }
      sel=0; for (i=1;i<=k;i++) if (ph_[i]==nat) sel=i
      if (!sel) { printf "0\tNO-NATIVE\t-\t-\t-\t-\t-\t%s\t%s\n", n, all; exit }
      d=hz[sel]-60; if (d<0) d=-d
      printf "%d\t%s\t%.2f\t%s\t%dx%d\t%.1fMHz\t%dx%d\t%s\t%s\n", (d<=0.15?1:0), (d<=0.15?"PASS":"FAIL"), hz[sel], nm[sel], w[sel], h[sel], c[sel]/1000000, ht[sel], vt[sel], n, all
    }'
done < <(find "$root" -type f -name '*.dtb' ! -name '*-uboot.dtb' -print0) >> "$tmp"

{
  printf 'VERDICT\tHZ\tNATIVE\tRES\tCLK\tTOTAL\tFILE\tALL NODES (Hz)\n'
  sort -t$'\t' -k1,1n -k8,8 "$tmp" | cut -f2-
} | column -t -s$'\t' > "$log"

cat "$log"
echo
awk -F'\t' '{c[$2]++} END{for(k in c) printf "%s: %d\n", k, c[k]}' "$tmp"
echo "leftover .dts:"; find "$root" -type f -name '*.dts'
rm -f "$tmp"
echo "log: $log"