#include "mfrc522_picc.h"
// NXP MFRC522 Rev 3.9 Register Addresses.
enum {
    CommandReg=0x01, ComIrqReg=0x04, ErrorReg=0x06,
    FIFODataReg=0x09, FIFOLevelReg=0x0A,
    ControlReg=0x0C, BitFramingReg=0x0D
};
// PCD_Idle=0x00, PCD_Transceive=0x0C; StartSend bit7.
static rc522_status_t write_reg(const rc522_bus_t *bus,uint8_t reg,uint8_t val)
{
    return bus->write(bus->ctx,reg,val)==0 ? RC522_OK : RC522_IO_ERROR;
}
static rc522_status_t read_reg(const rc522_bus_t *bus,uint8_t reg,uint8_t *val)
{
    return bus->read(bus->ctx,reg,val)==0 ? RC522_OK : RC522_IO_ERROR;
}

static rc522_status_t transceive(const rc522_bus_t *bus,
    const uint8_t *tx,size_t tx_len,uint8_t tx_last_bits,
    uint8_t *rx,size_t expected_len,uint32_t max_polls)
{
    uint8_t irq,err,level,last_bits,byte;
    size_t i;
    uint32_t tries;
    rc522_status_t rc;
    if(tx_len==0 || tx_len>64 || expected_len==0 || expected_len>64 ||
       max_polls==0 || tx_last_bits>7) return RC522_PROTOCOL_ERROR;
#define WR(REG,VALUE) do { rc=write_reg(bus,(REG),(VALUE)); if(rc) return rc; } while(0)
#define RD(REG,VALUE) do { rc=read_reg(bus,(REG),(VALUE)); if(rc) return rc; } while(0)
    WR(CommandReg,0x00);       // Idle
    WR(ComIrqReg,0x7F);        // Clear pending IRQ
    WR(FIFOLevelReg,0x80);     // Flush FIFO
    for(i=0;i<tx_len;i++) WR(FIFODataReg,tx[i]);
    WR(BitFramingReg,tx_last_bits); // BitFramingReg.TxLastBits
    WR(CommandReg,0x0C);      // Transceive
    WR(BitFramingReg,(uint8_t)(0x80u|tx_last_bits)); // StartSend

    irq=0;
    for(tries=0;tries<max_polls;tries++) {
        RD(ComIrqReg,&irq);
        if(irq & 0x30) break;    // RxIrq / IdleIrq
        if(irq & 0x01) break;    // TimerIrq
    }
    // Clear StartSend after device completion or timeout.
    WR(BitFramingReg,tx_last_bits);
    if(tries==max_polls || (irq & 0x01)) return RC522_TIMEOUT;
    RD(ErrorReg,&err);
    if(err & 0x08) return RC522_COLLISION;
    if(err & 0x13) return RC522_PROTOCOL_ERROR;
    RD(FIFOLevelReg,&level);
    RD(ControlReg,&last_bits);
    if(level!=expected_len || (last_bits & 0x07)!=0)
        return RC522_PROTOCOL_ERROR;
    for(i=0;i<expected_len;i++) {
        RD(FIFODataReg,&byte);
        rx[i]=byte;
    }
#undef WR
#undef RD
    return RC522_OK;
}
rc522_status_t rc522_read_uid4(const rc522_bus_t *bus,uint8_t uid[4],
                                uint8_t atqa[2],uint32_t max_polls)
{
    const uint8_t reqa=0x26;
    const uint8_t anticoll[2]={0x93,0x20};
    uint8_t answer[5];
    uint8_t bcc;
    rc522_status_t result;
    if(!bus || !bus->read || !bus->write || !uid || !atqa)
        return RC522_PROTOCOL_ERROR;
    result=transceive(bus,&reqa,1,7,atqa,2,max_polls);
    if(result!=RC522_OK) return result;
    result=transceive(bus,anticoll,2,0,answer,5,max_polls);
    if(result!=RC522_OK) return result;
    // 0x88 Cascade Tag: UID is 7/10 bytes; not supported in this lesson.
    if(answer[0]==0x88) return RC522_UNSUPPORTED_UID;
    bcc=(uint8_t)(answer[0]^answer[1]^answer[2]^answer[3]);
    if(bcc!=answer[4]) return RC522_PROTOCOL_ERROR;
    for(size_t i=0;i<4;i++) uid[i]=answer[i];
    return RC522_OK;
}
