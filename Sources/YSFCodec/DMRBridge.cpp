// GPL-3.0-or-later. DMR payload adapter from DroidStar dmr.cpp,
// Copyright (C) 2019-2021 Doug McLain. FEC copyright in the vendored files.
#include "include/YSFCodec.h"
#include "DMRDefines.h"
#include "cbptc19696.h"
#include "cgolay2087.h"
#include "crs129.h"
#include "CRCenc.h"
#include <cstring>
class DMRPayload {
public:
 uint32_t m_dmrid=0,m_txdstid=0,m_dmrcnt=0;
 uint8_t m_dataType=0,m_dmrFrame[55]{};
 FLCO m_flco=FLCO_GROUP;
 struct {uint8_t cc=1;} m_modeinfo;
 CBPTC19696 m_bptc;
 bool m_raw[128]{},m_data[72]{};
 void encode_header(uint8_t);void encode_data();void encode16114(bool*);
 void encode_qr1676(uint8_t*);void get_emb_data(uint8_t*,uint8_t);
 uint8_t get_embedded_data(uint8_t*,uint8_t);
 void encode_embedded_data();void bitsToByteBE(const bool*,uint8_t&);
 void byteToBitsBE(uint8_t,bool*);void lc_get_data(bool*);void lc_get_data(uint8_t*);
 void full_lc_encode(uint8_t*,uint8_t);void get_slot_data(uint8_t*);
 void addDMRDataSync(uint8_t*,bool);void addDMRAudioSync(uint8_t*,bool);
};
const uint32_t ENCODING_TABLE_1676[] =
	{0x0000U, 0x0273U, 0x04E5U, 0x0696U, 0x09C9U, 0x0BBAU, 0x0D2CU, 0x0F5FU, 0x11E2U, 0x1391U, 0x1507U, 0x1774U,
	 0x182BU, 0x1A58U, 0x1CCEU, 0x1EBDU, 0x21B7U, 0x23C4U, 0x2552U, 0x2721U, 0x287EU, 0x2A0DU, 0x2C9BU, 0x2EE8U,
	 0x3055U, 0x3226U, 0x34B0U, 0x36C3U, 0x399CU, 0x3BEFU, 0x3D79U, 0x3F0AU, 0x411EU, 0x436DU, 0x45FBU, 0x4788U,
	 0x48D7U, 0x4AA4U, 0x4C32U, 0x4E41U, 0x50FCU, 0x528FU, 0x5419U, 0x566AU, 0x5935U, 0x5B46U, 0x5DD0U, 0x5FA3U,
	 0x60A9U, 0x62DAU, 0x644CU, 0x663FU, 0x6960U, 0x6B13U, 0x6D85U, 0x6FF6U, 0x714BU, 0x7338U, 0x75AEU, 0x77DDU,
	 0x7882U, 0x7AF1U, 0x7C67U, 0x7E14U, 0x804FU, 0x823CU, 0x84AAU, 0x86D9U, 0x8986U, 0x8BF5U, 0x8D63U, 0x8F10U,
	 0x91ADU, 0x93DEU, 0x9548U, 0x973BU, 0x9864U, 0x9A17U, 0x9C81U, 0x9EF2U, 0xA1F8U, 0xA38BU, 0xA51DU, 0xA76EU,
	 0xA831U, 0xAA42U, 0xACD4U, 0xAEA7U, 0xB01AU, 0xB269U, 0xB4FFU, 0xB68CU, 0xB9D3U, 0xBBA0U, 0xBD36U, 0xBF45U,
	 0xC151U, 0xC322U, 0xC5B4U, 0xC7C7U, 0xC898U, 0xCAEBU, 0xCC7DU, 0xCE0EU, 0xD0B3U, 0xD2C0U, 0xD456U, 0xD625U,
	 0xD97AU, 0xDB09U, 0xDD9FU, 0xDFECU, 0xE0E6U, 0xE295U, 0xE403U, 0xE670U, 0xE92FU, 0xEB5CU, 0xEDCAU, 0xEFB9U,
	 0xF104U, 0xF377U, 0xF5E1U, 0xF792U, 0xF8CDU, 0xFABEU, 0xFC28U, 0xFE5BU};

void DMRPayload::encode_header(uint8_t t)
{
	addDMRDataSync(m_dmrFrame+20, 0);
	m_dataType = t;
	full_lc_encode(m_dmrFrame+20, t);
}

void DMRPayload::encode_data()
{
	uint32_t n_dmr = (m_dmrcnt - 1) % 6U;

	if (!n_dmr) {
		m_dataType = DT_VOICE_SYNC;
		addDMRAudioSync(m_dmrFrame+20, 0);
		encode_embedded_data();
	}
	else {
		m_dataType = DT_VOICE;
		uint8_t lcss = get_embedded_data(m_dmrFrame+20, n_dmr);
		get_emb_data(m_dmrFrame+20, lcss);
	}
}

void DMRPayload::encode16114(bool* d)
{
	d[11] = d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[5] ^ d[7] ^ d[8];
	d[12] = d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[6] ^ d[8] ^ d[9];
	d[13] = d[2] ^ d[3] ^ d[4] ^ d[5] ^ d[7] ^ d[9] ^ d[10];
	d[14] = d[0] ^ d[1] ^ d[2] ^ d[4] ^ d[6] ^ d[7] ^ d[10];
	d[15] = d[0] ^ d[2] ^ d[5] ^ d[6] ^ d[8] ^ d[9] ^ d[10];
}

void DMRPayload::encode_qr1676(uint8_t* data)
{
	uint32_t value = (data[0U] >> 1) & 0x7FU;
	uint32_t cksum = ENCODING_TABLE_1676[value];

	data[0U] = cksum >> 8;
	data[1U] = cksum & 0xFFU;
}

void DMRPayload::get_emb_data(uint8_t* data, uint8_t lcss)
{
	uint8_t DMREMB[2U];
	DMREMB[0U]  = (m_modeinfo.cc << 4) & 0xF0U;
	//DMREMB[0U] |= m_PI ? 0x08U : 0x00U;
	DMREMB[0U] |= (lcss << 1) & 0x06U;
	DMREMB[1U]  = 0x00U;

	encode_qr1676(DMREMB);

	data[13U] = (data[13U] & 0xF0U) | ((DMREMB[0U] >> 4U) & 0x0FU);
	data[14U] = (data[14U] & 0x0FU) | ((DMREMB[0U] << 4U) & 0xF0U);
	data[18U] = (data[18U] & 0xF0U) | ((DMREMB[1U] >> 4U) & 0x0FU);
	data[19U] = (data[19U] & 0x0FU) | ((DMREMB[1U] << 4U) & 0xF0U);
}

uint8_t DMRPayload::get_embedded_data(uint8_t* data, uint8_t n)
{
	if (n >= 1U && n < 5U) {
		n--;

		bool bits[40U];
		::memset(bits, 0x00U, 40U * sizeof(bool));
		::memcpy(bits + 4U, m_raw + n * 32U, 32U * sizeof(bool));

		uint8_t bytes[5U];
		bitsToByteBE(bits + 0U,  bytes[0U]);
		bitsToByteBE(bits + 8U,  bytes[1U]);
		bitsToByteBE(bits + 16U, bytes[2U]);
		bitsToByteBE(bits + 24U, bytes[3U]);
		bitsToByteBE(bits + 32U, bytes[4U]);

		data[14U] = (data[14U] & 0xF0U) | (bytes[0U] & 0x0FU);
		data[15U] = bytes[1U];
		data[16U] = bytes[2U];
		data[17U] = bytes[3U];
		data[18U] = (data[18U] & 0x0FU) | (bytes[4U] & 0xF0U);

		switch (n) {
		case 0U:
			return 1U;
		case 3U:
			return 2U;
		default:
			return 3U;
		}
	} else {
		data[14U] &= 0xF0U;
		data[15U]  = 0x00U;
		data[16U]  = 0x00U;
		data[17U]  = 0x00U;
		data[18U] &= 0x0FU;

		return 0U;
	}
}

void DMRPayload::encode_embedded_data()
{
	uint32_t crc;
	lc_get_data(m_data);
	CCRC::encodeFiveBit(m_data, crc);

	bool data[128U];
	::memset(data, 0x00U, 128U * sizeof(bool));

	data[106U] = (crc & 0x01U) == 0x01U;
	data[90U]  = (crc & 0x02U) == 0x02U;
	data[74U]  = (crc & 0x04U) == 0x04U;
	data[58U]  = (crc & 0x08U) == 0x08U;
	data[42U]  = (crc & 0x10U) == 0x10U;

	uint32_t b = 0U;
	for (uint32_t a = 0U; a < 11U; a++, b++)
		data[a] = m_data[b];
	for (uint32_t a = 16U; a < 27U; a++, b++)
		data[a] = m_data[b];
	for (uint32_t a = 32U; a < 42U; a++, b++)
		data[a] = m_data[b];
	for (uint32_t a = 48U; a < 58U; a++, b++)
		data[a] = m_data[b];
	for (uint32_t a = 64U; a < 74U; a++, b++)
		data[a] = m_data[b];
	for (uint32_t a = 80U; a < 90U; a++, b++)
		data[a] = m_data[b];
	for (uint32_t a = 96U; a < 106U; a++, b++)
		data[a] = m_data[b];

	// Hamming (16,11,4) check each row except the last one
	for (uint32_t a = 0U; a < 112U; a += 16U)
		encode16114(data + a);

	// Add the parity bits for each column
	for (uint32_t a = 0U; a < 16U; a++)
		data[a + 112U] = data[a + 0U] ^ data[a + 16U] ^ data[a + 32U] ^ data[a + 48U] ^ data[a + 64U] ^ data[a + 80U] ^ data[a + 96U];

	// The data is packed downwards in columns
	b = 0U;
	for (uint32_t a = 0U; a < 128U; a++) {
		m_raw[a] = data[b];
		b += 16U;
		if (b > 127U)
			b -= 127U;
	}
}

void DMRPayload::bitsToByteBE(const bool* bits, uint8_t& byte)
{
	byte  = bits[0U] ? 0x80U : 0x00U;
	byte |= bits[1U] ? 0x40U : 0x00U;
	byte |= bits[2U] ? 0x20U : 0x00U;
	byte |= bits[3U] ? 0x10U : 0x00U;
	byte |= bits[4U] ? 0x08U : 0x00U;
	byte |= bits[5U] ? 0x04U : 0x00U;
	byte |= bits[6U] ? 0x02U : 0x00U;
	byte |= bits[7U] ? 0x01U : 0x00U;
}

void DMRPayload::byteToBitsBE(uint8_t byte, bool* bits)
{
	bits[0U] = (byte & 0x80U) == 0x80U;
	bits[1U] = (byte & 0x40U) == 0x40U;
	bits[2U] = (byte & 0x20U) == 0x20U;
	bits[3U] = (byte & 0x10U) == 0x10U;
	bits[4U] = (byte & 0x08U) == 0x08U;
	bits[5U] = (byte & 0x04U) == 0x04U;
	bits[6U] = (byte & 0x02U) == 0x02U;
	bits[7U] = (byte & 0x01U) == 0x01U;
}

void DMRPayload::lc_get_data(bool* bits)
{
	uint8_t bytes[9U];
	memset(bytes, 0, 9);
	lc_get_data(bytes);

	byteToBitsBE(bytes[0U], bits + 0U);
	byteToBitsBE(bytes[1U], bits + 8U);
	byteToBitsBE(bytes[2U], bits + 16U);
	byteToBitsBE(bytes[3U], bits + 24U);
	byteToBitsBE(bytes[4U], bits + 32U);
	byteToBitsBE(bytes[5U], bits + 40U);
	byteToBitsBE(bytes[6U], bits + 48U);
	byteToBitsBE(bytes[7U], bits + 56U);
	byteToBitsBE(bytes[8U], bits + 64U);
}

void DMRPayload::lc_get_data(uint8_t *bytes)
{
	bool pf, r;
	uint8_t fid, options;
	bytes[0U] = (uint8_t)m_flco;

	pf = (bytes[0U] & 0x80U) == 0x80U;
	r  = (bytes[0U] & 0x40U) == 0x40U;
	//m_flco = FLCO(bytes[0U] & 0x3FU);
	fid = bytes[1U];
	options = bytes[2U];

	//bytes[0U] = (uint8_t)m_flco;

	if (pf)
		bytes[0U] |= 0x80U;

	if (r)
		bytes[0U] |= 0x40U;

	bytes[1U] = fid;
	bytes[2U] = options;
	bytes[3U] = m_txdstid >> 16;
	bytes[4U] = m_txdstid >> 8;
	bytes[5U] = m_txdstid >> 0;
	bytes[6U] = m_dmrid >> 16;
	bytes[7U] = m_dmrid >> 8;
	bytes[8U] = m_dmrid >> 0;
}

void DMRPayload::full_lc_encode(uint8_t* data, uint8_t type)  // for header
{
	uint8_t lcData[12U];
	uint8_t parity[4U];
	::memset(lcData, 0, sizeof(lcData));
	lc_get_data(lcData);

	CRS129::encode(lcData, 9U, parity);

	switch (type) {
		case DT_VOICE_LC_HEADER:
			lcData[9U]  = parity[2U] ^ VOICE_LC_HEADER_CRC_MASK[0U];
			lcData[10U] = parity[1U] ^ VOICE_LC_HEADER_CRC_MASK[1U];
			lcData[11U] = parity[0U] ^ VOICE_LC_HEADER_CRC_MASK[2U];
			break;

		case DT_TERMINATOR_WITH_LC:
			lcData[9U]  = parity[2U] ^ TERMINATOR_WITH_LC_CRC_MASK[0U];
			lcData[10U] = parity[1U] ^ TERMINATOR_WITH_LC_CRC_MASK[1U];
			lcData[11U] = parity[0U] ^ TERMINATOR_WITH_LC_CRC_MASK[2U];
			break;

		default:
			return;
	}
	get_slot_data(data);
	m_bptc.encode(lcData, data);
}

void DMRPayload::get_slot_data(uint8_t* data)
{
	uint8_t DMRSlotType[3U];
	DMRSlotType[0U]  = (m_modeinfo.cc << 4) & 0xF0U;
	DMRSlotType[0U] |= (m_dataType  << 0) & 0x0FU;
	DMRSlotType[1U]  = 0x00U;
	DMRSlotType[2U]  = 0x00U;

	CGolay2087::encode(DMRSlotType);

	data[12U] = (data[12U] & 0xC0U) | ((DMRSlotType[0U] >> 2) & 0x3FU);
	data[13U] = (data[13U] & 0x0FU) | ((DMRSlotType[0U] << 6) & 0xC0U) | ((DMRSlotType[1U] >> 2) & 0x30U);
	data[19U] = (data[19U] & 0xF0U) | ((DMRSlotType[1U] >> 2) & 0x0FU);
	data[20U] = (data[20U] & 0x03U) | ((DMRSlotType[1U] << 6) & 0xC0U) | ((DMRSlotType[2U] >> 2) & 0x3CU);
}

void DMRPayload::addDMRDataSync(uint8_t* data, bool duplex)
{
	if (duplex) {
		for (uint32_t i = 0U; i < 7U; i++)
			data[i + 13U] = (data[i + 13U] & ~SYNC_MASK[i]) | BS_SOURCED_DATA_SYNC[i];
	} else {
		for (uint32_t i = 0U; i < 7U; i++)
			data[i + 13U] = (data[i + 13U] & ~SYNC_MASK[i]) | MS_SOURCED_DATA_SYNC[i];
	}
}

void DMRPayload::addDMRAudioSync(uint8_t* data, bool duplex)
{
	if (duplex) {
		for (uint32_t i = 0U; i < 7U; i++)
			data[i + 13U] = (data[i + 13U] & ~SYNC_MASK[i]) | BS_SOURCED_AUDIO_SYNC[i];
	} else {
		for (uint32_t i = 0U; i < 7U; i++)
			data[i + 13U] = (data[i + 13U] & ~SYNC_MASK[i]) | MS_SOURCED_AUDIO_SYNC[i];
	}
}
void dmr_encode_payload(uint32_t source,uint32_t destination,uint8_t private_call,uint8_t color_code,uint8_t kind,uint32_t voice_index,const uint8_t *ambe27,uint8_t *out33){
 DMRPayload p;p.m_dmrid=source;p.m_txdstid=destination;p.m_flco=private_call?FLCO_USER_USER:FLCO_GROUP;p.m_modeinfo.cc=color_code;
 if(kind==0 || kind==2){p.encode_header(kind==0?DT_VOICE_LC_HEADER:DT_TERMINATOR_WITH_LC);}
 else {
  memcpy(p.m_dmrFrame+20,ambe27,13);
  p.m_dmrFrame[33]=ambe27[13]&0xf0;p.m_dmrFrame[39]=ambe27[13]&0x0f;
  memcpy(p.m_dmrFrame+40,ambe27+14,13);
  p.m_dmrcnt=voice_index+1;
  p.encode_embedded_data();p.encode_data();
 }
 memcpy(out33,p.m_dmrFrame+20,33);
}
int dmr_decode_lc(const uint8_t *payload,uint8_t kind,uint8_t *out12){
 if(kind!=0 && kind!=2)return 0;
 CBPTC19696 b;b.decode(payload,out12);uint8_t parity[4]{};CRS129::encode(out12,9,parity);
 uint8_t mask=kind==0?0x96:0x99;
 return out12[9]==(parity[2]^mask) && out12[10]==(parity[1]^mask) && out12[11]==(parity[0]^mask);
}
