# 4-bit Array Multiplier: RTL to GDSII (SKY130)

## Team

| Name | Roll number |
|------|-------------|
| TODO | TODO        |
| TODO | TODO        |

## Environment

All tools (Icarus Verilog, GTKWave, Yosys, OpenSTA, OpenROAD, KLayout, Magic, Netgen, LibreLane)
come from the LibreLane Nix shell. The SKY130 PDK is managed by `ciel`.

```sh
# one-time: enable the PDK version pinned by LibreLane
ciel enable --pdk-family sky130 8afc8346a57fe1ab7934ba5a6056ea8b43078e71

# in ~/.bashrc
export PDK_ROOT=$HOME/.ciel
export PDK=sky130A

# every session: enter the Nix shell, then the repo
cd ~/Documents/DVD/tools/librelane && nix develop
cd ~/Documents/DVD/mult_array
```

Always run the commands below inside the Nix shell. The system `/usr/bin/yosys` (0.9) and
`/usr/bin/iverilog` (11.0) are older versions and must not be used.

## Commands run (in order)

TODO
