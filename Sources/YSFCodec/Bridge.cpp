// FusionLab, GPL-3.0-or-later. V/D2 transformation adapted from DroidStar
// ysf.cpp, Copyright (C) 2019-2021 Doug McLain. See THIRD_PARTY.md.
#include "include/YSFCodec.h"
#include "YSFFICH.h"
#include <cstring>
static const uint8_t whitening[13]={0x93,0xd7,0x51,0x21,0x9c,0x2f,0x6c,0xd0,0xef,0x0f,0xf8,0x3d,0xf1};
static const int dvsi[49]={0,3,6,9,12,15,18,21,24,27,30,33,36,39,41,43,45,47,1,4,7,10,13,16,19,22,25,28,31,34,37,40,42,44,46,48,2,5,8,11,14,17,20,23,26,29,32,35,38};
static bool bit(const uint8_t *p,int i){return (p[i/8]>>(7-i%8))&1;}
static void put(uint8_t *p,int i,bool b){if(b)p[i/8]|=0x80>>(i%8);else p[i/8]&=~(0x80>>(i%8));}
int ysf_decode_dn(const uint8_t *p,size_t n,uint8_t *out,uint8_t *fi,uint8_t *dt){
 if(!p||!out||!fi||!dt||n!=120)return -1;
 const uint8_t sync[]={0xd4,0x71,0xc9,0x63,0x4d};
 if(memcmp(p,sync,5))return -1;
 CYSFFICH f;if(!f.decode(p))return -1;*fi=f.getFI();*dt=f.getDT();
 if(*fi!=1||*dt!=2)return 0;
 memset(out,0,35);
 for(int j=0;j<5;j++){
  uint8_t v[13]={};const uint8_t *voice=p+35+j*18;
  for(int i=0;i<104;i++)put(v,i,bit(voice,(i%26)*4+i/26));
  for(int i=0;i<13;i++)v[i]^=whitening[i];
  for(int i=0;i<49;i++){
   // Majority correct each repetition-coded bit, then restore DVSI ordering.
   bool b=i<27 ? (int(bit(v,i*3))+int(bit(v,i*3+1))+int(bit(v,i*3+2))>=2) : bit(v,81+i-27);
   put(out+j*7,dvsi[i],b);
  }
 }
 return 5;
}
void ysf_test_payload(const uint8_t *a,uint8_t *p,uint8_t fi,uint8_t dt){
 memset(p,0,120);const uint8_t sync[]={0xd4,0x71,0xc9,0x63,0x4d};memcpy(p,sync,5);
 CYSFFICH f;f.setFI(fi);f.setDT(dt);f.setFT(7);f.encode(p);
 for(int j=0;j<5;j++){
  uint8_t v[13]={};for(int i=0;i<49;i++){
   bool b=bit(a+j*7,dvsi[i]);if(i<27){for(int k=0;k<3;k++)put(v,i*3+k,b);}else put(v,81+i-27,b);
  }
  for(int i=0;i<13;i++)v[i]^=whitening[i];
  for(int i=0;i<104;i++)put(p+35+j*18,(i%26)*4+i/26,bit(v,i));
 }
}

#include "YSFConvolution.h"
#include "CRCenc.h"
static const uint8_t whiteData[20]={0x93,0xd7,0x51,0x21,0x9c,0x2f,0x6c,0xd0,0xef,0x0f,0xf8,0x3d,0xf1,0x73,0x20,0x94,0xed,0x1e,0x7c,0xd8};
// DCH: whiten + CRC-16 + convolutional code + 20-row pair interleave.
// Header: 20 data bytes -> 45 coded bytes; V/D2: 10 -> 25.
static void dataChannel(const uint8_t *data,int count,uint8_t *p,int lane){
 uint8_t input[25]={},coded[45]={},interleaved[45]={};
 for(int i=0;i<count;i++)input[i]=data[i]^whiteData[i];
 CCRC::addCCITT162(input,count+2);
 const int bits=(count+2)*8+4;
 CYSFConvolution conv;conv.encode(input,coded,bits);
 const int columns=count==20?9:5;
 for(int i=0;i<bits;i++){
  int dest=(i%columns)*40+(i/columns)*2;
  put(interleaved,dest,bit(coded,i*2));put(interleaved,dest+1,bit(coded,i*2+1));
 }
 const int chunk=count==20?9:5;
 for(int j=0;j<5;j++)memcpy(p+30+j*18+lane,interleaved+j*chunk,chunk);
}
void ysf_encode_dn(const uint8_t *call,const uint8_t *ambe,uint8_t fi,uint8_t fn,uint8_t *p){
 // Reuse the V/D2 voice transform, then set the actual on-air FICH and DCH.
 ysf_test_payload(ambe,p,fi,2);
 CYSFFICH f;f.setFI(fi);f.setCS(2);f.setDT(2);f.setFN(fi==1?fn%7:0);f.setFT(6);f.encode(p);
 if(fi==0||fi==2){
  uint8_t csd1[20],csd2[20];memset(csd1,'*',10);memcpy(csd1+10,call,10);
  memcpy(csd2,call,10);memcpy(csd2+10,call,10);
  dataChannel(csd1,20,p,0);dataChannel(csd2,20,p,9);
 }else{
  uint8_t d[10];memset(d,' ',10);
  switch(fn%7){case 0:memset(d,'*',10);break;case 1:case 2:case 3:memcpy(d,call,10);break;case 6:memset(d,0,10);break;default:break;}
  dataChannel(d,10,p,0);
 }
}
