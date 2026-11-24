#include "../sw/mfrc522_picc.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

// Fake MFRC522 register device. This tests command flow and BCC,
// NOT real RF link timing or analog antenna behavior.
typedef struct {
    uint8_t regs[64];
    uint8_t fifo_tx[64],fifo_rx[64],tx_len,rx_len,rx_pos;
    uint8_t bcc_fail, uid_cascade, no_card;
    unsigned transceive_count;
} fake_t;
static int wr(void *context,uint8_t reg,uint8_t value)
{
    fake_t *m=(fake_t*)context;
    if(reg>=64) return -1;
    m->regs[reg]=value;
    if(reg==0x0A && (value & 0x80)) {
        m->tx_len=0;m->rx_len=0;m->rx_pos=0;
    } else if(reg==0x09) {
        if(m->tx_len>=64) return -1;
        m->fifo_tx[m->tx_len++]=value;
    } else if(reg==0x01 && value==0x0C) {
        m->transceive_count++;
        m->regs[0x04]=0;
        if(m->no_card) return 0;
        if(m->tx_len==1 && m->fifo_tx[0]==0x26) {
            m->fifo_rx[0]=0x04;m->fifo_rx[1]=0x00;
            m->rx_len=2;m->regs[0x04]=0x30;
        } else if(m->tx_len==2 && m->fifo_tx[0]==0x93 &&
                  m->fifo_tx[1]==0x20) {
            m->fifo_rx[0]=m->uid_cascade ? 0x88 : 0x12;
            m->fifo_rx[1]=0x34;m->fifo_rx[2]=0x56;m->fifo_rx[3]=0x78;
            m->fifo_rx[4]=m->fifo_rx[0]^m->fifo_rx[1]^
                           m->fifo_rx[2]^m->fifo_rx[3];
            if(m->bcc_fail) m->fifo_rx[4]^=0x01;
            m->rx_len=5;m->regs[0x04]=0x30;
        } else return -1;
    }
    return 0;
}
static int rd(void *context,uint8_t reg,uint8_t *value)
{
    fake_t *m=(fake_t*)context;
    if(reg>=64 || !value) return -1;
    if(reg==0x09) {
        if(m->rx_pos>=m->rx_len) return -1;
        *value=m->fifo_rx[m->rx_pos++];
    } else if(reg==0x0A) *value=m->rx_len;
    else *value=m->regs[reg];
    return 0;
}
static rc522_status_t run(fake_t *f,uint8_t uid[4])
{
    const rc522_bus_t bus={f,rd,wr};
    uint8_t atqa[2]={0};
    rc522_status_t rc=rc522_read_uid4(&bus,uid,atqa,12);
    if(rc==RC522_OK && (atqa[0]!=0x04 || atqa[1]!=0x00))
        return RC522_PROTOCOL_ERROR;
    return rc;
}
int main(void)
{
    fake_t f;uint8_t uid[4]={0};
    memset(&f,0,sizeof(f));
    assert(run(&f,uid)==RC522_OK);
    assert(uid[0]==0x12 && uid[1]==0x34 && uid[2]==0x56 && uid[3]==0x78);
    assert(f.transceive_count==2);
    printf("P2_13_UID4_MOCK_REQA_ANTICOLL_PASS\n");
    memset(&f,0,sizeof(f));f.bcc_fail=1;
    assert(run(&f,uid)==RC522_PROTOCOL_ERROR);
    printf("P2_13_UID4_MOCK_BCC_REJECT_PASS\n");
    memset(&f,0,sizeof(f));f.uid_cascade=1;
    assert(run(&f,uid)==RC522_UNSUPPORTED_UID);
    printf("P2_13_UID4_MOCK_CASCADE_REJECT_PASS\n");
    memset(&f,0,sizeof(f));f.no_card=1;
    assert(run(&f,uid)==RC522_TIMEOUT);
    printf("P2_13_UID4_MOCK_TIMEOUT_PASS\n");
    assert(rc522_read_uid4(0,uid,uid,10)==RC522_PROTOCOL_ERROR);
    printf("P2_13_UID4_C_HOST_PASS\n");
    return 0;
}
