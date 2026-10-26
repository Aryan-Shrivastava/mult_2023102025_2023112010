# 4-bit Array Multiplier: RTL to GDSII (SKY130)

## Team

| Name | Roll number |
|------|-------------|
| Aryan Shrivastava | 2023102025 |
| Kiruba Pandi Selvakumar | 2023112010 |

## Environment

All tools (Icarus Verilog, GTKWave, Yosys, OpenSTA, OpenROAD, KLayout, Magic, Netgen, LibreLane)
come from the LibreLane Nix shell instead of the IIC-OSIC-TOOLS Docker image. The SKY130 PDK is
managed by `ciel`.

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

If `nix develop` hangs before the shell opens, the FOSSi binary cache is unreachable. All tools are
already installed, so use `nix develop --offline`.

Always run the commands below inside the Nix shell. The system `/usr/bin/yosys` (0.9) and
`/usr/bin/iverilog` (11.0) are older versions and must not be used.

| Tool | Version |
|---|---|
| LibreLane | 3.0.14 |
| Icarus Verilog | 13.0 (devel) |
| Yosys | 0.62 |
| OpenSTA | 2.7.0 |
| OpenROAD | dcf36133 |
| KLayout | 0.30.7 |
| Magic | 8.3.623 |
| SKY130 PDK (open_pdks) | 8afc8346a57fe1ab7934ba5a6056ea8b43078e71 |

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

### Part D: Physical design (RTL to GDSII) with LibreLane

#### D1. Configuration

`pnr/config.json` sets `DESIGN_NAME`, `VERILOG_FILES`, `CLOCK_PORT`, `FP_SIZING` = `"absolute"` and
`DIE_AREA` = `[0, 0, 150, 150]` as required, and

```
CLOCK_PERIOD = 1.2 × Tmin, rounded up to the next 0.5 ns
             = 1.2 × 2.983 = 3.58  →  4.0 ns
```

#### D2. Run the flow

```sh
cd pnr
librelane config.json
cd ..
```

Each run creates `pnr/runs/RUN_<date>_<time>/` (in `.gitignore`; it is large). The flow ends with
`Flow complete.` and a summary listing `Antenna`, `LVS` and `DRC`, each `Passed ✅`.

#### D3. Runs

Setup slack is judged at the typical corner (`nom_tt_025C_1v80`), the same corner as Part C,
which is defined at the typical corner only. At that corner the first run already has positive
slack (+1.167 ns), so no further runs were needed.

`metrics.json` also contains the worst slack over all corners, `timing__setup__ws` = −1.254 ns.
It comes from the slow corner (`ss_100C_1v60`: slow transistors, 100 °C, 1.60 V), which
LibreLane reports as a warning only; the flow still ends with `Flow complete.` It is recorded
below for completeness.

| Run | CLOCK_PERIOD | Setup slack, tt (ns) | Setup slack, all corners (ns) | DRC | LVS | Result |
|---|---|---|---|---|---|---|
| `RUN_2026-10-21_00-43-05` | 4.0 ns | +1.167 | −1.254 (`max_ss_100C_1v60`) | 0 | 0 | ✅ final |

#### D4. Copy the results from the final run

```sh
RUN=$(ls -d pnr/runs/RUN_* | tail -1)
cp $RUN/final/metrics.json pnr/metrics.json
cp $RUN/final/gds/mult_array.gds pnr/mult_array.gds
```

#### D5. Read the numbers from `pnr/metrics.json`

```sh
grep -E '"design__instance__count(__stdcell)?"|core__area|die__area|"route__wirelength"' pnr/metrics.json
grep -E '"timing__setup__ws(__corner:nom_tt_025C_1v80)?"' pnr/metrics.json
grep -E '"(magic|klayout)__drc_error__count"|"route__drc_errors"|"design__lvs_error__count"' pnr/metrics.json
```

| Metric | Key | Value |
|---|---|---|
| Cells after place and route | `design__instance__count` | 4795 |
| Core area | `design__core__area` | 17759.5 µm² |
| Die area | `design__die__area` | 22500 µm² |
| Wirelength | `route__wirelength` | 2610 µm |
| Setup slack (tt) | `timing__setup__ws__corner:nom_tt_025C_1v80` | +1.167 ns |
| Setup slack (all corners, for reference) | `timing__setup__ws` | −1.254 ns (`ss_100C_1v60`, warning only) |
| DRC errors | `magic__drc_error__count`, `klayout__drc_error__count`, `route__drc_errors` | 0, 0, 0 |
| LVS errors | `design__lvs_error__count` | 0 |

```
Post-route Fmax = 1000 / (CLOCK_PERIOD − setup slack) = 1000 / (4.0 − 1.167) = 353.0 MHz
```

#### D6. Cells added by the flow

Counted from the final placed design (`$RUN/final/def/mult_array.def`) by cell name:

```sh
DEF=$(ls -d pnr/runs/RUN_* | tail -1)/final/def/mult_array.def
awk '/^COMPONENTS/{f=1;next} /^END COMPONENTS/{f=0} f && /^ *-/{print $3}' $DEF \
  | sed 's/sky130_fd_sc_hd__//' | sort | uniq -c | sort -rn
```

| Kind | Cells | Count |
|---|---|---|
| Decap | `decap_3` | 4170 |
| Fill | `fill_1`, `fill_2` | 276 |
| Tap | `tapvpwrvgnd_1` | 245 |
| Buffers | `clkdlybuf4s25_1` ×19 (inputs, outputs, reset fanout), `buf_2` ×12 (timing repair), `clkbuf_16` ×3 (clock tree), `dlygate4sd3_1` ×2 (hold fix) | 36 |
| Logic and flip-flops | 52 logic gates, 16 × `dfrtp_2` | 68 |
| **Total** | | **4795** |

#### D7. View the layout

```sh
klayout pnr/mult_array.gds
```

#### D8. Simulate the post-route netlist

LVS proves the layout matches the post-route netlist; these runs prove that netlist still
multiplies correctly. LibreLane re-synthesizes the design and adds buffers, so it is not the Part B
netlist. Temporary files go into the run folder, which is in `.gitignore`.

Functional simulation with the Part A testbench:

```sh
RUN=$(ls -d pnr/runs/RUN_* | tail -1)
CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o $RUN/gls_pr \
  tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v $RUN/final/nl/mult_array.nl.v
(cd $RUN && vvp -n gls_pr | grep -E "^(PASS|FAIL)")    # PASS: 256 vectors checked, 0 errors
```

Timing simulation with the post-route typical-corner delays (SDF) at the real 4.0 ns clock:

```sh
# the PDK model of the unused lpflow_bleeder_1 cell breaks Icarus in timing mode; drop that line
grep -v "(SHORT => VPWR)" $CELLS/sky130_fd_sc_hd.v > $RUN/cells_timing.v
SDF=$PWD/$RUN/final/sdf/nom_tt_025C_1v80/mult_array__nom_tt_025C_1v80.sdf
sed -e 's/localparam CLK_PERIOD = 10;/localparam CLK_PERIOD = 4;/' \
    -e "s|\$dumpvars(0, tb_mult);|\$dumpvars(0, tb_mult); \$sdf_annotate(\"$SDF\", dut);|" \
    tb/tb_mult.v > $RUN/tb_sdf.v
iverilog -g2012 -gspecify -ginterconnect -o $RUN/tsim \
  $RUN/tb_sdf.v $CELLS/primitives.v $RUN/cells_timing.v $RUN/final/nl/mult_array.nl.v \
  2> $RUN/tsim_compile.log
(cd $RUN && vvp -n tsim | grep -E "^(PASS|FAIL)")      # PASS: 256 vectors checked, 0 errors
```

The compile log holds about 480 `Timing checks are not supported` warnings, and the simulation
reports `TIMINGCHECK not supported` and `Chosen value not defined` twice. All are harmless: Icarus
skips setup/hold checks, which STA covers. With `CLOCK_PERIOD = 2` in the `sed` line
the same simulation fails, which shows the delays are applied.
