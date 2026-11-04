#pragma once
#include <stdint.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct MD380Context MD380Context;
MD380Context *md380_create(const char *library,const uint8_t *firmware,size_t firmware_size,const uint8_t *ram,size_t ram_size,char *error,size_t capacity);
void md380_destroy(MD380Context *context);
int md380_encode_frame(MD380Context *context,const int16_t *pcm,uint8_t *voice,int bits,char *error,size_t capacity);
int md380_decode_frame(MD380Context *context,const uint8_t *voice,int bits,int16_t *pcm,char *error,size_t capacity);
void md380_fec_encode(const uint8_t *raw,uint8_t *coded);
void md380_fec_decode(const uint8_t *coded,uint8_t *raw);
#ifdef __cplusplus
}
#endif
