#pragma once
#include <stdint.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
// -1 invalid FICH, 0 other frame/mode, 5 decoded V/D2 blocks.
int ysf_decode_dn(const uint8_t *payload, size_t length, uint8_t *ambe35, uint8_t *fi, uint8_t *dt);
// Local test fixture only. This app never transmits these frames.
void ysf_test_payload(const uint8_t *ambe35, uint8_t *payload120, uint8_t fi, uint8_t dt);
#ifdef __cplusplus
}
#endif
#ifdef __cplusplus
extern "C" {
#endif
// Produces a complete YSF radio payload. fi: 0 header, 1 V/D2 voice, 2 EOT.
// call10 and ambe35 must point to 10 and 35 bytes respectively.
void ysf_encode_dn(const uint8_t *call10, const uint8_t *ambe35, uint8_t fi, uint8_t fn, uint8_t *payload120);
#ifdef __cplusplus
}
#endif

#ifdef __cplusplus
extern "C" {
#endif
void dmr_encode_payload(uint32_t source,uint32_t destination,uint8_t private_call,uint8_t color_code,uint8_t kind,uint32_t voice_index,const uint8_t *ambe27,uint8_t *out33);
int dmr_decode_lc(const uint8_t *payload,uint8_t kind,uint8_t *out12);
#ifdef __cplusplus
}
#endif
