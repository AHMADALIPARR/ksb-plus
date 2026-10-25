/ Layer 0 tests. Run via run-tests.sh, which feeds src/l00.k then
/ this file to Kona (Kona's \l is unreliable here, so the runner
/ concatenates instead of loading).
/ Each chk prints PASS name or FAIL name. The last line prints
/ ALL PASS only when every check passed; run-tests.sh also fails the
/ file if any FAIL line appears.
FC:(,0)
chk:{[n;g;w] m:g~w; FC[0]:FC[0]+(~m); (:[m; "PASS "; "FAIL "]),n}
chk["valid-bytes"; bValid[0 65 255]; 1]
chk["valid-empty"; bValid[!0]; 1]
chk["invalid-256"; bValid[0 256]; 0]
chk["invalid-neg"; bValid[0 -1]; 0]
chk["invalid-atom"; bValid[5]; 0]
chk["u8-roundtrip"; bDecU8[bEncU8[255]]; 255]
chk["u16-known"; bEncU16[513]; 2 1]
chk["u16-roundtrip"; bDecU16[bEncU16[65535]]; 65535]
chk["u32-known"; bEncU32[16909060]; 1 2 3 4]
chk["u32-roundtrip"; bDecU32[bEncU32[4294967295]]; 4294967295]
chk["u32-zero"; bDecU32[bEncU32[0]]; 0]
chk["i8-neg"; bDecI8[bEncI8[-128]]; -128]
chk["i8-pos"; bDecI8[bEncI8[127]]; 127]
chk["i16-roundtrip"; bDecI16[bEncI16[-32768]]; -32768]
chk["i32-min"; bDecI32[bEncI32[-2147483648]]; -2147483648]
chk["i32-max"; bDecI32[bEncI32[2147483647]]; 2147483647]
chk["u64-roundtrip"; bDecU64[bEncU64[4294967295;4294967295]]; (4294967295;4294967295)]
chk["u64-zero"; bDecU64[bEncU64[0;0]]; (0;0)]
chk["cksum-abc"; bCksum[65 66 67]; 26017991]
chk["cksum-empty"; bCksum[!0]; 1]
chk["str-roundtrip"; bDecStr[bEncStr[_ic "hello"]]; (1;_ic "hello";!0)]
chk["str-short"; bDecStr[1 2]; (0;"short";!0)]
chk["str-length"; bDecStr[bEncStr[_ic "hi"],99]; (0;"length";!0)]
chk["frame-roundtrip"; bUnframe[bFrame[7;_ic "hello"]]; (1;7;_ic "hello")]
chk["frame-empty-payload"; bUnframe[bFrame[0;!0]]; (1;0;!0)]
chk["frame-short"; bUnframe[1 2 3]; (0;"short";!0)]
chk["frame-magic"; bUnframe[99,1 _ bFrame[7;_ic "hi"]]; (0;"magic";!0)]
chk["frame-length"; bUnframe[bFrame[7;_ic "hi"],0]; (0;"length";!0)]
fr:bFrame[7;_ic "hi"]
fr[4]:2
chk["frame-version"; bUnframe[fr]; (0;"version";!0)]
fr:bFrame[7;_ic "hi"]
fr[10]:fr[10]+1
chk["frame-checksum"; bUnframe[fr]; (0;"checksum";!0)]
chk["utf8-ascii"; butf8ok[_ic "hello"]; 1]
chk["utf8-2byte"; butf8ok[195 169]; 1]
chk["utf8-3byte"; butf8ok[226 130 172]; 1]
chk["utf8-4byte"; butf8ok[240 159 152 128]; 1]
chk["utf8-empty"; butf8ok[!0]; 1]
chk["utf8-overlong"; butf8ok[192 128]; 0]
chk["utf8-surrogate"; butf8ok[237 160 128]; 0]
chk["utf8-truncated"; butf8ok[226 130]; 0]
chk["utf8-badcont"; butf8ok[226 65 172]; 0]
chk["utf8-lonecont"; butf8ok[,128]; 0]
chk["utf8-too-high"; butf8ok[245 128 128 128]; 0]
:[0=FC[0]; "ALL PASS"; "FAILURES"]
