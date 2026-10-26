# Generate GPL DroidStar reference vectors. Usage: python3 script/generate_dmr_vectors.py /path/to/original/dmr.cpp
# Original dmr.cpp: Copyright (C) 2019-2021 Doug McLain, GPL-3.0-or-later.
from pathlib import Path
import re,subprocess,json,sys,tempfile
scratch=Path(tempfile.mkdtemp(prefix="FusionLab-DMR-reference-"))
root=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1]).read_text()
names={'build_frame','encode_header','encode_data','encode16114','encode_qr1676','get_emb_data','get_embedded_data','encode_embedded_data','bitsToByteBE','byteToBitsBE','lc_get_data','full_lc_encode','get_slot_data','addDMRDataSync','addDMRAudioSync'}
parts=[]
for match in re.finditer(r'(?:void|uint8_t) DMR::(\w+)\([^\n]*',source):
 if match.group(1) not in names:continue
 brace=source.index('{',match.end());depth=1;end=brace+1
 while depth:
  depth += (source[end]=='{')-(source[end]=='}');end+=1
 parts.append(source[match.start():end])
table=source[source.index('const uint32_t ENCODING_TABLE_1676'):source.index('DMR::DMR()')]
header='''// Reference uses original DroidStar functions, not FusionLab DMRBridge.
#include "DMRDefines.h"
#include "cbptc19696.h"
#include "cgolay2087.h"
#include "crs129.h"
#include "CRCenc.h"
#include <cstring>
#include <cstdio>
class DMR {
public:
 uint32_t m_dmrid=2040001,m_txsrcid=2040001,m_txdstid=9990,m_essid=204000101,m_txstreamid=0x12345678,m_dmrcnt=0;
 uint8_t m_txslot=2,m_dataType=0,m_dmrFrame[55]{};
 FLCO m_flco=FLCO_USER_USER;
 struct {uint32_t cc=1,srcid=0,dstid=0,gwid=0,frame_number=0;} m_modeinfo;
 CBPTC19696 m_bptc;bool m_raw[128]{},m_data[72]{};
 void build_frame();void encode_header(uint8_t);void encode_data();void encode16114(bool*);
 void encode_qr1676(uint8_t*);void get_emb_data(uint8_t*,uint8_t);uint8_t get_embedded_data(uint8_t*,uint8_t);
 void encode_embedded_data();void bitsToByteBE(const bool*,uint8_t&);void byteToBitsBE(uint8_t,bool*);
 void lc_get_data(bool*);void lc_get_data(uint8_t*);void full_lc_encode(uint8_t*,uint8_t);
 void get_slot_data(uint8_t*);void addDMRDataSync(uint8_t*,bool);void addDMRAudioSync(uint8_t*,bool);
};
'''
main='''
int main(){DMR d;uint8_t ambe[27];for(int i=0;i<27;i++)ambe[i]=(i*37+11)&255;
 for(int n=0;n<=9;n++){
  d.m_dmrcnt=n;
  if(n==0||n==9)d.encode_header(n==0?DT_VOICE_LC_HEADER:DT_TERMINATOR_WITH_LC);
  else {memcpy(d.m_dmrFrame+20,ambe,13);d.m_dmrFrame[33]=ambe[13]&0xf0;d.m_dmrFrame[39]=ambe[13]&15;memcpy(d.m_dmrFrame+40,ambe+14,13);d.encode_data();}
  d.build_frame();for(int i=0;i<55;i++)printf("%02x",d.m_dmrFrame[i]);printf("\\n");
 }
}
'''
cpp=(scratch/'Reference.cpp');cpp.write_text(header+table+'\n\n'.join(parts)+main)
vendor=root/'Sources/YSFCodec'
cmd=['clang++','-std=c++17','-I',str(vendor),str(cpp)]+[str(vendor/x) for x in ['cbptc19696.cpp','chamming.cpp','cgolay2087.cpp','crs129.cpp','CRCenc.cpp']]+['-o',str(scratch/'reference')]
subprocess.run(cmd,check=True)
lines=subprocess.check_output([str(scratch/'reference')],text=True).splitlines()
result={('header' if i==0 else 'end' if i==9 else f'voice-{i-1}'):line for i,line in enumerate(lines)}
(root/'Tests/Fixtures/DroidStarDMR.json').write_text(json.dumps(result,indent=2)+'\n')
print('Generated',len(result),'independent reference frame vectors')
