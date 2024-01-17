import re

pattern = r'([\w\.-]+)? \((\d+\.\d+\.\d+\.\d+)\) at \(?([0-9a-fA-F:]+)?\)? on'
lines = [
    "? (172.16.24.1) at fc:ec:da:7b:3b:57 on en0 ifscope [ethernet]",
    "? (172.16.24.13) at 94:9f:3e:d7:2d:66 on en0 ifscope [ethernet]",
    "? (172.16.24.16) at 4e:52:54:dd:1d:79 on en0 ifscope [ethernet]",
    "? (172.16.24.21) at da:a2:50:e0:52:82 on en0 ifscope [ethernet]",
    "? (172.16.24.22) at 4:92:26:b7:b2:77 on en0 ifscope [ethernet]",
    "? (172.16.24.60) at b4:fb:e4:6d:6a:1f on en0 ifscope [ethernet]",
    "? (172.16.24.66) at (incomplete) on en0 ifscope [ethernet]",
    "? (172.16.24.68) at 8c:7a:aa:e8:94:f5 on en0 ifscope [ethernet]",
    "? (172.16.24.74) at b0:4a:39:9d:19:38 on en0 ifscope [ethernet]",
    "? (172.16.24.75) at 88:63:df:a6:d7:97 on en0 ifscope [ethernet]",
    "? (172.16.24.78) at 4:92:26:b7:b2:78 on en0 ifscope [ethernet]",
    "? (172.16.24.80) at 4:92:26:b7:b2:79 on en0 ifscope [ethernet]",
    "? (172.16.24.81) at 94:9f:3e:d7:2d:66 on en0 ifscope [ethernet]",
    "? (172.16.24.82) at 6:b5:e0:89:d6:9b on en0 ifscope [ethernet]",
    "? (172.16.24.83) at f4:d4:88:92:4a:13 on en0 ifscope permanent [ethernet]",
    "? (172.16.24.89) at (incomplete) on en0 ifscope [ethernet]",
    "? (172.16.24.95) at 38:d5:47:2:79:91 on en0 ifscope [ethernet]",
    "? (172.16.24.234) at (incomplete) on en0 ifscope [ethernet]",
    "? (172.16.24.255) at ff:ff:ff:ff:ff:ff on en0 ifscope [ethernet]",
    "mdns.mcast.net (224.0.0.251) at 1:0:5e:0:0:fb on en0 ifscope permanent [ethernet]",
    "? (239.255.102.18) at 1:0:5e:7f:66:12 on en0 ifscope permanent [ethernet]",
    "? (239.255.255.250) at 1:0:5e:7f:ff:fa on en0 ifscope permanent [ethernet]"
]

for line in lines:
    match = re.search(pattern, line)
    if match:
        print("Matched:", line)
        print("Group 1:", match.group(1))
        print("Group 2:", match.group(2))
        print("Group 3:", match.group(3))
        print("\n")
