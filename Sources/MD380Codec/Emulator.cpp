#include "include/MD380Codec.h"
#include "vendor/unicorn/unicorn.h"
#include <dlfcn.h>
#include <cstdio>
#include <cstring>
#include <memory>
#include <string>

struct MD380Context {
 void *library=nullptr;
 uc_engine *encoder=nullptr,*decoder=nullptr;
 decltype(&uc_open) open=nullptr;
 decltype(&uc_close) close=nullptr;
 decltype(&uc_ctl) ctl=nullptr;
 decltype(&uc_mem_map) map=nullptr;
 decltype(&uc_mem_write) write=nullptr;
 decltype(&uc_mem_read) read=nullptr;
 decltype(&uc_reg_write) set=nullptr;
 decltype(&uc_reg_read) get=nullptr;
 decltype(&uc_emu_start) run=nullptr;
 decltype(&uc_strerror) describe=nullptr;
 std::string error;
 ~MD380Context(){if(close){if(encoder)close(encoder);if(decoder)close(decoder);}if(library)dlclose(library);}
 bool check(uc_err status){if(status==UC_ERR_OK)return true;error=describe ? describe(status):"Unicorn error";return false;}
 bool initialize(uc_engine **engine,const uint8_t *fw,size_t fwSize,const uint8_t *ram,size_t ramSize){
  return check(open(UC_ARCH_ARM,uc_mode(UC_MODE_THUMB|UC_MODE_MCLASS),engine)) &&
   check(ctl(*engine,UC_CTL_WRITE(UC_CTL_CPU_MODEL,1),UC_CPU_ARM_CORTEX_M4)) &&
   check(map(*engine,0x08000000,0x100000,UC_PROT_ALL)) && check(write(*engine,0x0800c000,fw,fwSize)) &&
   check(map(*engine,0x20000000,0x40000,UC_PROT_ALL)) && check(write(*engine,0x20000000,ram,ramSize)) &&
   check(map(*engine,0x30000000,0x10000,UC_PROT_ALL)) && check(map(*engine,0x100000,0x1000,UC_PROT_ALL));
 }
 bool call(uc_engine *engine,uint32_t address,const uint32_t *args,size_t count){
  const int regs[]={UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3};
  for(size_t i=0;i<4;i++)if(!check(set(engine,regs[i],&args[i])))return false;
  uint32_t sp=0x3000f000,lr=0x100001,pc=0;
  if(!check(set(engine,UC_ARM_REG_SP,&sp)) || !check(set(engine,UC_ARM_REG_LR,&lr)) ||
     !check(write(engine,sp,args+4,(count-4)*4)) ||
     !check(run(engine,address,0x100000,50000,2000000)) || !check(get(engine,UC_ARM_REG_PC,&pc)))return false;
  if(pc!=0x100000){error="MD380 execution limit reached";return false;}
  return true;
 }
};
static void message(char *out,size_t capacity,const char *text){if(out && capacity)snprintf(out,capacity,"%s",text);}
extern "C" MD380Context *md380_create(const char *library,const uint8_t *fw,size_t fwSize,const uint8_t *ram,size_t ramSize,char *error,size_t capacity){
 if(fwSize!=994304 || ramSize!=131072){message(error,capacity,"Unexpected MD380 firmware size");return nullptr;}
 auto c=std::make_unique<MD380Context>();c->library=dlopen(library,RTLD_NOW|RTLD_LOCAL);
 if(!c->library){message(error,capacity,dlerror());return nullptr;}
 #define LOAD(member,name) c->member=reinterpret_cast<decltype(c->member)>(dlsym(c->library,name));if(!c->member){message(error,capacity,"Incomplete Unicorn library: " name);return nullptr;}
 LOAD(open,"uc_open") LOAD(close,"uc_close") LOAD(ctl,"uc_ctl") LOAD(map,"uc_mem_map") LOAD(write,"uc_mem_write") LOAD(read,"uc_mem_read")
 LOAD(set,"uc_reg_write") LOAD(get,"uc_reg_read") LOAD(run,"uc_emu_start") LOAD(describe,"uc_strerror")
 #undef LOAD
 if(!c->initialize(&c->encoder,fw,fwSize,ram,ramSize) || !c->initialize(&c->decoder,fw,fwSize,ram,ramSize)){message(error,capacity,c->error.c_str());return nullptr;}
 return c.release();
}
extern "C" void md380_destroy(MD380Context *c){delete c;}
extern "C" int md380_encode_frame(MD380Context *c,const int16_t *pcm,uint8_t *voice,int bits,char *error,size_t capacity){
 if(!c || (bits!=49 && bits!=72)){message(error,capacity,"Invalid MD380 encoder input");return 0;}
 int16_t blank[49]={0},raw[49];uint8_t packed[7]={0};
 bool ok=c->check(c->write(c->encoder,0x2000de82,pcm,320)) && c->check(c->write(c->encoder,0x2000dfc6,blank,sizeof(blank)));
 for(uint32_t half=0;ok && half<2;half++){
  uint32_t args[]={0x2000dfc6,0,0x2000de82+half*160,80,0x1840,half,0x2000,0x2000c730};
  ok=c->call(c->encoder,0x08050d91,args,8);
 }
 ok=ok && c->check(c->read(c->encoder,0x2000dfc6,raw,sizeof(raw)));
 if(!ok){message(error,capacity,c->error.c_str());return 0;}
 for(int i=0;i<49;i++)if(raw[i])packed[i/8]|=1<<(7-i%8);
 if(bits==49)memcpy(voice,packed,7);else md380_fec_encode(packed,voice);
 return 1;
}
extern "C" int md380_decode_frame(MD380Context *c,const uint8_t *voice,int bits,int16_t *pcm,char *error,size_t capacity){
 if(!c || (bits!=49 && bits!=72)){message(error,capacity,"Invalid MD380 decoder input");return 0;}
 uint8_t packed[7];int16_t raw[49];
 if(bits==49)memcpy(packed,voice,7);else md380_fec_decode(voice,packed);
 for(int i=0;i<49;i++)raw[i]=(packed[i/8]>>(7-i%8))&1;
 bool ok=c->check(c->write(c->decoder,0x20011c8e,raw,sizeof(raw)));
 for(uint32_t half=0;ok && half<2;half++){
  uint32_t args[]={0x20011aa8+half*160,80,0x20011c8e,0,0,half,0x20011224};
  ok=c->call(c->decoder,0x08051249,args,7);
 }
 ok=ok && c->check(c->read(c->decoder,0x20011aa8,pcm,320));
 if(!ok){message(error,capacity,c->error.c_str());return 0;}
 return 1;
}
