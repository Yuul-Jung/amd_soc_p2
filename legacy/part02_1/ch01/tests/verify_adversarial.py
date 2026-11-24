from pathlib import Path
from html.parser import HTMLParser
import subprocess, re, tempfile


class DocumentParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.links = []
        self.images = []
        self.text = []
        self.has_title = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        if tag == "a" and "href" in attrs:
            self.links.append(attrs["href"])
        if tag == "img" and "src" in attrs:
            self.images.append(attrs["src"])
        if tag == "title":
            self.has_title = True

    def handle_data(self, data):
        self.text.append(data)


def parse_html(path):
    parser = DocumentParser()
    parser.feed(path.read_text())
    return parser


D=Path(__file__).resolve().parent.parent
assert (D/'P2_01_main.c').exists()
src=(D/'P2_01_main.c').read_text()
expected=['"LED ON"','"LED OFF"','"STATUS"','Xil_Out32(', 'Xil_In32(', 'read_command_line(', 'handle_command(', 'report_status(']
for phrase in expected:assert phrase in src,phrase
# no old single-char commands in the comparator
assert not re.search(r"command\s*==\s*\(u8\)\s*'[^']'",src)
# link checks, nav anchors, exact source insertion in explanation (escaped HTML becomes same string)
links=[]
for fname in ['P2_01_Study_Guide.html','P2_01_C_Explained.html','P2_01_AXI_Explained.html']:
    doc=parse_html(D/fname)
    for url in doc.links:
        if url.startswith(('http://','https://','mailto:')):continue
        path,sep,fragment=url.partition('#')
        target=(D/path) if path else D/fname
        assert target.exists(),(fname,url)
        if fragment:
            dest=parse_html(target) if target.suffix=='.html' else doc
            assert fragment in dest.ids,(fname,fragment)
        links.append((fname,url))
    for image in doc.images:
        assert (D/image).exists(),(fname,image)
    assert '<html' in (D/fname).read_text().lower() and doc.has_title
assert src.strip() in ''.join(parse_html(D/'P2_01_C_Explained.html').text), 'full source mismatch'
for fname in ['P2_01_Study_Guide.html','P2_01_C_Explained.html','P2_01_C_Flow.mmd']:
    t=(D/fname).read_text()
    for command in ['LED ON','LED OFF','STATUS']: assert command in t,(fname,command)
# generated flowchart matches function names & command contract
svg=(D/'P2_01_C_Flow.svg').read_text()
for token in ['LED ON','LED OFF','STATUS','read_command_line','handle_command','Xil_In32','Xil_Out32']:
    assert token in svg,token
assert 'width=' in svg and 'viewBox=' in svg
# mock BSP, serial and register behavior: gcc with warnings as errors
stubs=D/'tests'/'test_stubs'
temporary_directory=tempfile.TemporaryDirectory()
exe=Path(temporary_directory.name)/'test_host_exe'
cmd=['gcc','-std=c11','-O1','-Wall','-Wextra','-Werror','-pedantic','-DUSER_IP_BASEADDR=0x44A00000U','-I'+str(stubs),str(D/'P2_01_main.c'),str(D/'tests'/'test_host.c'),'-o',str(exe)]
subprocess.run(cmd,check=True,capture_output=True)
# Ensure address missing is a compile FAIL as intended
bad=subprocess.run(['gcc','-std=c11','-I'+str(stubs),'-fsyntax-only',str(D/'P2_01_main.c')],capture_output=True,text=True)
assert bad.returncode!=0 and 'USER_IP_BASEADDR' in bad.stderr
cases=[
 ('normal',b'LED ON\r\nSTATUS\r\nLED OFF\n', ['OK LED=ON REG0=0x00000001','STATUS LED=ON REG0=0x00000001','OK LED=OFF REG0=0x00000000'], 0),
 ('unknown_then_recovery',b'1\n0\nr\nLEDON\nLED ON\n', ['ERROR: use LED ON / LED OFF / STATUS','OK LED=ON REG0=0x00000001'],4),
 ('case_sensitive',b'led on\nLed On\nSTATUS\n', ['ERROR: use LED ON / LED OFF / STATUS','STATUS LED=OFF REG0=0x00000000'],2),
 ('empty_and_crlf',b'\r\n\r\nLED ON\r\n\nSTATUS\r', ['OK LED=ON REG0=0x00000001','STATUS LED=ON REG0=0x00000001'],0),
 ('overflow_resync',b'A'*100+b'\nLED ON\n', ['ERROR: command too long (max 31)','OK LED=ON REG0=0x00000001'],0),
 ('near_limit',b'A'*31+b'\n'+b'A'*32+b'\nSTATUS\n', ['ERROR: use LED ON / LED OFF / STATUS','ERROR: command too long (max 31)','STATUS LED=OFF REG0=0x00000000'],1),
 ('whitespace_not_accepted',b' LED ON\nLED OFF \nLED ON\n', ['ERROR: use LED ON / LED OFF / STATUS','OK LED=ON REG0=0x00000001'],2),
 ('lf_only',b'STATUS\nLED ON\n', ['STATUS LED=OFF REG0=0x00000000','OK LED=ON REG0=0x00000001'],0),
 ('cr_only',b'STATUS\rLED OFF\r', ['STATUS LED=OFF REG0=0x00000000','OK LED=OFF REG0=0x00000000'],0),
 ('embedded_nul',b'LED ON\x00ATTACK\nSTATUS\n', ['ERROR: invalid character','STATUS LED=OFF REG0=0x00000000'],0),
 ('invalid_after_state',b'LED ON\nLED OFF\x1b\nSTATUS\n', ['OK LED=ON REG0=0x00000001','ERROR: invalid character','STATUS LED=ON REG0=0x00000001'],0),
 ('overflow_fake_cmd',b'LED ON'+b'X'*50+b'\nSTATUS\n', ['ERROR: command too long (max 31)','STATUS LED=OFF REG0=0x00000000'],0),
]
results=[]
for name,input_,must,errors in cases:
    r=subprocess.run([str(exe)],input=input_,capture_output=True,timeout=5,check=True)
    s=r.stdout.decode()
    for v in must:assert v in s,(name,v,s)
    assert s.count('ERROR: use LED ON / LED OFF / STATUS')==errors,(name,s.count('ERROR: use LED ON / LED OFF / STATUS'),errors)
    results.append(f'{name}: PASS')
# top ownership: LED0 single owner, old bit0 is unused, other LED bits retain GPIO
T=(D/'P2_01_basys3_top.v').read_text()
assert '.p2_led_o(ip_led0)' in T and '.led_tri_o(gpio_led)' in T and 'assign led = {gpio_led[15:1], ip_led0};' in T
print('STATIC CONTRACT PASS, LINKS:',len(links),'HOST TESTS:',len(cases))
