from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parent.parent
SRC=ROOT/'sw/main_p2_02.c'
STUB=ROOT/'tests/test_stubs'
BIN=ROOT/'tests/.host_runner'
base=['gcc','-std=c11','-O1','-Wall','-Wextra','-Werror','-pedantic','-I',str(STUB)]
flags=['-DUSER_IP_BASEADDR=0x44A00000U','-DFND_IP_BASEADDR=0x44A10000U']
subprocess.run(base+flags+[str(SRC),str(ROOT/'tests/test_host.c'),'-o',str(BIN)],check=True,capture_output=True)
for tag,macros,expect in [
    ('no-base',[],'USER_IP_BASEADDR'),
    ('no-fnd',['-DUSER_IP_BASEADDR=0x44A00000U'],'FND_IP_BASEADDR'),
    ('collision',['-DUSER_IP_BASEADDR=0x44A00000U','-DFND_IP_BASEADDR=0x44A00000U'],'must be different'),
]:
    p=subprocess.run(base+macros+['-fsyntax-only',str(SRC)],text=True,capture_output=True)
    assert p.returncode!=0 and expect in p.stderr,(tag,p.stderr)

cases=[
 ('main',b'LED ON\r\nDISP 1234\r\nDISP 0050\r\nSTATUS\r\nDISP OFF\r\nLED OFF\r\n',
  ['OK LED=ON REG0=0x00000001','OK DISP=1234 REG0=0x00001234 REG1=0x00000001','OK DISP=0050 REG0=0x00000050 REG1=0x00000001','STATUS DISP=0050','OK DISP=OFF VALUE=0050','OK LED=OFF REG0=0x00000000'],0),
 ('zero_not_off',b'DISP 0000\nSTATUS\n',
  ['OK DISP=0000 REG0=0x00000000 REG1=0x00000001','STATUS DISP=0000'],0),
 ('max_digits',b'DISP 9999\nDISP OFF\nSTATUS\n',
  ['OK DISP=9999 REG0=0x00009999 REG1=0x00000001','STATUS DISP=OFF VALUE=9999'],0),
 ('invalid_length',b'DISP 123\nDISP 12345\nDISP 50\nSTATUS\n',
  ['ERROR: LED ON / LED OFF / DISP dddd / DISP OFF / STATUS','STATUS DISP=OFF VALUE=0000'],3),
 ('invalid_digits',b'DISP 12A4\nDISP -123\nDISP 12 4\nDISP 123a\n',
  ['ERROR: LED ON / LED OFF / DISP dddd / DISP OFF / STATUS'],4),
 ('case_and_spaces',b'disp 1234\nDISP 1234 \n DISP 1234\nDISP 1234\n',
  ['OK DISP=1234 REG0=0x00001234 REG1=0x00000001'],3),
 ('overflow_resync',b'DISP 1234'+b'X'*40+b'\nDISP 0050\n',
  ['ERROR: command too long (max 31)','OK DISP=0050'],0),
 ('nul_bad',b'DISP 1234\x00MALWARE\nSTATUS\n',
  ['ERROR: invalid character','STATUS DISP=OFF VALUE=0000'],0),
 ('crlf_and_empty',b'\r\n\nDISP 0050\r\n\nDISP OFF\rSTATUS\r',
  ['OK DISP=0050','OK DISP=OFF VALUE=0050','STATUS DISP=OFF VALUE=0050'],0),
 ('not_one_character',b'1\n0\nr\nLED ON\nSTATUS\n',
  ['ERROR: LED ON / LED OFF / DISP dddd / DISP OFF / STATUS','OK LED=ON'],3),
 ('state_stable_after_invalid',b'DISP 1234\nDISP 12AB\nSTATUS\n',
  ['OK DISP=1234','STATUS DISP=1234'],1),
 ('upper_bound',b'Z'*31+b'\n'+b'Z'*32+b'\nSTATUS\n',
  ['ERROR: command too long (max 31)','STATUS DISP=OFF VALUE=0000'],1),
]
for name,stdin,wants,error_count in cases:
    p=subprocess.run([str(BIN)],input=stdin,capture_output=True,timeout=5)
    s=p.stdout.decode('ascii')
    assert p.returncode==0,(name,p.stderr)
    for want in wants:
        assert want in s,(name,want,s)
    assert s.count('ERROR: LED ON / LED OFF / DISP dddd / DISP OFF / STATUS')==error_count,(name,s)
    print('HOST_CASE',name,'PASS')
print('MOCK_BSP_COMPILE PASS')
print('ADDRESS_GUARD PASS')
print('HOST_CASES',len(cases),'PASS')
BIN.unlink()
