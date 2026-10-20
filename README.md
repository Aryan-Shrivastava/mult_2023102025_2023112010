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

### Part C: Static timing analysis with OpenSTA

#### C1. Run at T = 10 ns

```sh
sta sta/sta.tcl
```

`sta/sta.tcl` reads the typical-corner Liberty file and `synth/mult_array_netlist.v`, defines a
clock on `clk` with period `T` (default 10 ns), sets a 1.0 ns input delay on every input except
`clk` and a 1.0 ns output delay on every output, prints the worst setup slack and writes the
critical path to `sta/mult_array_timing.rpt`. The script ends with `exit`, so `sta` returns to
the shell instead of waiting at its `%` prompt.

Output:

```
Clock period T = 10.0 ns
worst slack max 7.017
```

#### C2. Find Tmin and Fmax, then re-run at Tmin

```
Tmin = T - WNS = 10 - 7.017 = 2.983 ns   (rounded to 0.01 ns: 2.98 ns)
Fmax = 1000 / Tmin = 1000 / 2.983 = 335.2 MHz
```

```sh
T=2.98 sta sta/sta.tcl
```

Output:

```
Clock period T = 2.98 ns
worst slack max -0.003
```

The slack is 0.003 ns below zero because 2.98 ns is 2.983 ns rounded down, which confirms Tmin.
The critical path is the same at both periods. The committed `sta/mult_array_timing.rpt` is from
the T = 10 ns run (`sta sta/sta.tcl` reproduces it).

#### C3. Critical path (from `sta/mult_array_timing.rpt`, path group `clk`)

Start point: `_109_` (`dfrtp_1`, input register `a_r[1]`).
End point: `_107_` (`dfrtp_1`, output register `p[7]`, D = `c3[4]`).

| # | Cell | Type | Delay (ns) | Arrival (ns) | Signal in the RTL |
|---|---|---|---|---|---|
| 1 | `_109_` | `dfrtp_1` (clock to Q) | 0.396 | 0.396 | `a_r[1]` |
| 2 | `_054_` | `a22o_1` | 0.248 | 0.644 | row 1, full adder 1 (`pp1[1]`, `r0[1]`), merged with the partial-product ANDs |
| 3 | `_055_` | `and3_1` | 0.181 | 0.824 | row 1, full adder 1 |
| 4 | `_058_` | `nor3_1` | 0.276 | 1.101 | `c2[1]`: carry of row 2, full adder 0 |
| 5 | `_070_` | `xnor3_1` | 0.453 | 1.554 | `s2[1]` (= `r2[0]`): sum of row 2, full adder 1 |
| 6 | `_071_` | `and3_1` | 0.209 | 1.763 | `c3[1]`: carry of row 3, full adder 0 (`pp3[0]` AND `r2[0]`) |
| 7 | `_085_` | `maj3_1` | 0.361 | 2.124 | `c3[2]`: carry of row 3, full adder 1 |
| 8 | `_097_` | `maj3_1` | 0.379 | 2.503 | `c3[3]`: carry of row 3, full adder 2 |
| 9 | `_098_` | `maj3_1` | 0.349 | 2.852 | `c3[4]`: carry of row 3, full adder 3 |
| | `_107_` | `dfrtp_1` (setup 0.131) | | 2.852 | `p[7]` |

The signal mapping was found by simulating the netlist and the RTL together on all 256 inputs
and matching each netlist wire on the path to an RTL signal.
