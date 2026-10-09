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

All commands are run from the repository root, inside the Nix shell.

### Part A: RTL design and verification

#### A1. Compile and run the testbench

```sh
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim
```

Expected output:

```
VCD info: dumpfile mult.vcd opened for output.
PASS: 256 vectors checked, 0 errors
tb/tb_mult.v:...: $finish called at 7700000 (1ps)
```

The testbench (`tb/tb_mult.v`):
- generates a 10 ns clock and holds `rst_n` low for the first 2 cycles (0–20 ns);
- applies all 256 pairs (`a`, `b` = 0…15) on falling clock edges, one pair every 30 ns;
- checks two things for every pair:
  - **latency:** after the first rising edge, `p` must still hold the previous product
    (prints `LATENCY: ...` if `p` changes too early);
  - **product:** after the second rising edge, `p` must equal `a * b`
    (prints `MISMATCH: ...` otherwise);
- prints one summary line, `PASS: 256 vectors checked, 0 errors` or `FAIL: ... N errors`,
  where N is the number of failing pairs;
- writes the waveform to `mult.vcd`.

Re-run both commands after editing any `.v` file. `vvp sim` alone runs the old compiled version.
`sim` and `mult.vcd` are in `.gitignore`.

#### A2. View the waveform in GTKWave

```sh
gtkwave mult.vcd &
```

1. In the **SST** panel (top left), click `tb_mult`. Select `clk`, `rst_n`, `a`, `b` and `p`
   (Ctrl-click) and click **Append**. Use the signals under `tb_mult`, not under `dut`.
2. Select `a`, `b` and `p` in the **Signals** panel, then right-click → **Data Format → Decimal**.
3. Go to the example. Pair number `k = a × 16 + b` is applied at `30 + 30k` ns:

   | Example (roll number used) | Inputs applied | Edge 1: inputs captured, `p` unchanged | Edge 2: `p` updates |
   |---|---|---|---|
   | 10 × 7 (2023102025) | 5040 ns | 5045 ns (`p` = 60, previous product) | 5055 ns (`p` = 70) |
   | 5 × 7 (2023112010)  | 2640 ns | 2645 ns (`p` = 30, previous product) | 2655 ns (`p` = 35) |

   Type the range into the **From** / **To** boxes in the toolbar (for example `5030 ns` to
   `5070 ns`) and press Enter.
4. Mark the latency: **Markers → Drop Named Marker** at the input change, edge 1 and edge 2.
   `p` changes only at edge 2, which shows the 2-cycle latency.
5. After re-running the simulation, use **File → Reload Waveform** (Ctrl+Shift+R).

#### A3. Check that the testbench catches errors (Part A task 6)

Temporarily break the full adder, re-run, confirm `FAIL`, then restore the file:

```sh
sed -i 's/assign sum  = a ^ b ^ cin;/assign sum  = a ^ b;/' rtl/full_adder.v
grep "assign sum" rtl/full_adder.v      # shows: assign sum  = a ^ b;
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim | grep -E "^(PASS|FAIL)"        # FAIL: 256 vectors checked, 95 errors

git checkout rtl/full_adder.v           # restore the committed version
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim | grep -E "^(PASS|FAIL)"        # PASS: 256 vectors checked, 0 errors
```

`vvp sim | head` shows the first mismatches; open the waveform at the first mismatch's time to debug.

### Part B: Logic synthesis with Yosys

#### B1. Synthesize

```sh
yosys -c synth/synth.tcl
```

`synth/synth.tcl` reads the RTL, runs `synth -top mult_array -flatten`, maps flip-flops
(`dfflibmap`) and logic (`abc`) to `sky130_fd_sc_hd` cells using the typical-corner Liberty file
(`$PDK_ROOT/sky130A/.../sky130_fd_sc_hd__tt_025C_1v80.lib`), and writes:
- `synth/mult_array_stat.rpt`: cell counts and area;
- `synth/mult_array_netlist.v`: the gate-level netlist (only `sky130_fd_sc_hd__*` cells).

`PDK_ROOT` must be set (see Environment), or Yosys stops with `can't read "::env(PDK_ROOT)"`.

#### B2. Read the results

```sh
cat synth/mult_array_stat.rpt
```

- **Total cells:** the number on the `cells` line.
- **Flip-flops:** the count of `sky130_fd_sc_hd__dfrtp_1` (should be 16).
- **Total area:** the `Chip area for module '\mult_array'` line.
- **Flip-flop area and %:** the `of which used for sequential elements` line
  (= 16 × area of one `dfrtp_1`).

#### B3. Simulate the synthesized netlist

```sh
CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls \
  tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v
vvp gls
```

Expected: `PASS: 256 vectors checked, 0 errors`. Same testbench as Part A, but the design is now the
netlist, with the SKY130 cell models (`primitives.v`, `sky130_fd_sc_hd.v`) providing each cell's
behaviour. `gls` is in `.gitignore`.
