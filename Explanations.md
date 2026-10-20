# 4-bit Array Multiplier — Explanations

Reference notes for the Digital VLSI assignment (4-bit array multiplier, RTL to GDSII on SKY130).
Each section answers one question. New questions are added at the end.

## Contents
1. [Why does the ripple-row array use 12 full adders?](#1-why-does-the-ripple-row-array-use-12-full-adders)
2. [Can a more efficient gate-level multiplier be built?](#2-can-a-more-efficient-gate-level-multiplier-be-built)
3. [Do we still need 12 full adders if the rows use 4-bit carry-lookahead adders?](#3-do-we-still-need-12-full-adders-if-the-rows-use-4-bit-carry-lookahead-adders)
4. [Which parts of the assignment force the ripple-carry structure?](#4-which-parts-of-the-assignment-force-the-ripple-carry-structure)
5. [What is RTL? Is it gate-level Verilog?](#5-what-is-rtl-is-it-gate-level-verilog)
6. [How do I run the testbench and GTKWave myself?](#6-how-do-i-run-the-testbench-and-gtkwave-myself)
7. [How do I check that the Part C timing results are correct?](#7-how-do-i-check-that-the-part-c-timing-results-are-correct)

---

## 1. Why does the ripple-row array use 12 full adders?

### Short answer
A 4 × 4 multiplication produces **4 partial products**. Adding 4 numbers together takes
**3 additions**. Each addition is done by a **4-bit ripple-carry adder**, which is
**4 full adders**. So:

```
3 adder rows × 4 full adders per row = 12 full adders
```

In general, an N × N array multiplier needs **(N − 1) rows × N full adders = N(N − 1)** full adders.

### Step 1 — Where the partial products come from
Multiplying binary numbers is shift-and-add. For each bit `b_i` of B, the partial product is
A ANDed with `b_i`, shifted left by `i` places:

```
pp_i[j] = a[j] AND b[i]        (i, j = 0 … 3)
```

That is 4 partial products × 4 bits = **16 AND gates**. The AND gates *make* the partial
products; the full adders *add them up*.

### Step 2 — Why 3 adder rows, not 4
Adding K numbers with two-input adders always takes K − 1 additions:

```
pp0 + pp1         → first addition  (row 1)
    (result) + pp2 → second addition (row 2)
    (result) + pp3 → third addition  (row 3)
```

Row 0 has **no adders**: the first partial product has nothing to be added to yet, so it is
just passed down. With 4 partial products there are 4 − 1 = **3 adder rows**.

### Step 3 — Why each row is only 4 bits wide
The final product is 8 bits, so it might seem that each adder must be 8 bits wide. It doesn't,
because each row "retires" one bit:

- Partial product `pp_i` is shifted left by `i`, so it never affects product bits below `p[i]`.
- After row `i` adds `pp_i`, its **lowest sum bit is final**. It becomes `p[i]` and leaves
  the array.
- Only the remaining **3 sum bits + the carry out** (4 bits) are passed down to the next row.
- The next row adds those 4 bits to the next 4-bit partial product, so it only needs a
  **4-bit adder**.

So every row adds two 4-bit numbers, which takes 4 full adders. The carry out of the top
full adder becomes the 4th bit passed down.

### Step 4 — Why "ripple-row"
Inside each row, the carry from full adder `j` feeds the carry-in of full adder `j + 1`. The
carry ripples along the row, like a ripple-carry adder. That is where the name comes from.

### The structure (4 × 4)

```
              a[3:0] & b[0]    → Row 0: 4 AND gates, no adders     → p[0]
                    │ passes down r0 = {0, pp0[3], pp0[2], pp0[1]}
                    ▼
a[3:0] & b[1] → Row 1: 4 AND + FA FA FA FA (carry ripples →)     → p[1]
                    │ passes down r1 = {c1[4], s1[3], s1[2], s1[1]}
                    ▼
a[3:0] & b[2] → Row 2: 4 AND + FA FA FA FA                        → p[2]
                    │ passes down r2 = {c2[4], s2[3], s2[2], s2[1]}
                    ▼
a[3:0] & b[3] → Row 3: 4 AND + FA FA FA FA                        → p[3], p[7:4]

Totals: 16 AND gates, 12 full adders
```

Inputs of full adder `j` in row `i` (i = 1 … 3, j = 0 … 3):
`pp_i[j]`, `r_(i−1)[j]`, and carry `c_i[j]` (with `c_i[0] = 0`).

### Worked example: 11 × 13 = 143
A = 1011, B = 1101.

| Row | Partial product | Bits passed in | 4-bit add | Carry out | Product bit retired | Passed down |
|---|---|---|---|---|---|---|
| 0 | pp0 = 1011 (b0 = 1) | — | — | — | p[0] = 1 | r0 = 0101 |
| 1 | pp1 = 0000 (b1 = 0) | 0101 | 0101 + 0000 = 0101 | 0 | p[1] = 1 | r1 = 0010 |
| 2 | pp2 = 1011 (b2 = 1) | 0010 | 0010 + 1011 = 1101 | 0 | p[2] = 1 | r2 = 0110 |
| 3 | pp3 = 1011 (b3 = 1) | 0110 | 0110 + 1011 = 1 0001 | 1 | p[3] = 1 | p[7:4] = 1000 |

Result: p = **1000 1111** = 128 + 15 = **143** ✓

### How the count scales

| N (bits) | AND gates (N²) | Adder rows (N − 1) | Full adders N(N − 1) |
|---|---|---|---|
| 2 | 4 | 1 | 2 |
| 4 | 16 | 3 | **12** |
| 8 | 64 | 7 | 56 |
| 16 | 256 | 15 | 240 |

The adder count grows as N², so area grows roughly quadratically. The critical path grows
roughly linearly, about 2N full-adder delays.

### Note: 4 of the 12 full adders are "wasted"
Four of the 12 full adders have a constant 0 on one input:

- The lowest full adder in each of rows 1, 2 and 3 has carry-in `c_i[0] = 0` (3 adders).
- The top full adder in row 1 gets `r0[3] = 0` (1 adder).

A full adder with one input fixed at 0 behaves like a **half adder**. A minimal design would
use **8 full adders + 4 half adders**. The assignment still requires 12 `full_adder`
instances because the structure is regular and easy to check. Yosys removes the constant
logic during synthesis anyway, which is one reason the synthesized cell count is not simply
16 + 12 (report question 1).

---

## 2. Can a more efficient gate-level multiplier be built?

*Context: the reference diagram (`multiplier_gatelvl.png`, from Mano's* Digital Design*) is a
4-bit × 3-bit ripple-row array: 12 AND gates, two 4-bit adders, outputs C0–C6. The assignment
is the 4 × 4 version of the same structure.*

Yes. The main options, from simplest to most aggressive:

### a) Half adders where an input is constant 0 (saves area)
As explained in section 1, full adders with a 0 input can become half adders (one XOR + one AND).
For 4 × 4, 12 FA becomes **8 FA + 4 HA**. In general: N(N − 2) full adders + N half adders.
Synthesis does this automatically through constant propagation.

### b) Carry-save array (shorter critical path)
In the ripple-row array, a carry can run sideways along a row and then down into the next row.
In a **carry-save array**, each full adder's carry goes **diagonally down to the next row**
instead of along its own row, so no row waits for its own carries. All carries are resolved
once in a final **vector-merging adder** at the bottom.

- With a ripple final adder: about (N − 1) array stages plus an N-bit ripple.
- With a fast final adder (carry-lookahead or carry-select): the final stage drops to about log N.
- Similar number of cells, and the layout stays regular.

### c) Wallace / Dadda tree (fastest for wide multipliers)
Ignore the rows completely. Take all N² partial-product bits and reduce them column by column,
using full adders as 3-input → 2-output counters running in parallel, then finish with one
fast adder.

- Delay: **O(log N)** reduction stages instead of O(N).
- Cost: irregular wiring, harder to lay out.
- Standard for 16-bit and wider multipliers.

### d) Booth encoding (fewer partial products)
Radix-4 Booth recoding halves the number of partial products (N → about N/2), at the cost of
encoder and multiplexer logic. Mainly worth it for **signed** and **wide** operands. For a
4-bit unsigned multiplier the extra logic costs more than it saves.

### Comparison for 4 × 4

| Design | Adders | Critical path |
|---|---|---|
| Ripple-row array (assignment) | 12 FA | about 2N = 8 FA delays |
| Array with half adders | 8 FA + 4 HA | slightly shorter; mainly saves area |
| Carry-save array + fast final adder | about the same | about N + log N |
| Wallace/Dadda + fast final adder | about the same or fewer | about log N + log N |

### Conclusion
For 4 bits the gains are small. Only the half-adder substitution clearly helps, and synthesis
already does it. The speed-oriented designs start to pay off at around 8 bits and above. For
example, an 8-bit ripple-row array needs 56 full adders and about 16 full-adder delays, which is
where carry-save or Wallace designs become worthwhile.

For the assignment itself, keep the required structure: `mult_array.v` must contain
**12 `full_adder` instances** wired as in the Section 2 table of the guide. These alternatives
are useful material for report questions 1 and 6.

---

## 3. Do we still need 12 full adders if the rows use 4-bit carry-lookahead adders?

### Short answer
**No full adders in the usual sense, but still 12 one-bit "slices".** Each row still has to add
two 4-bit numbers, so there are still 3 rows × 4 bit positions = 12 places where two bits are
added. What changes is *how the carries are made*:

- **Ripple-carry row:** 4 full adders. Each full adder computes its own carry-out and passes it
  to the next one.
- **Carry-lookahead (CLA) row:** 4 **partial full adders** (they make sum, generate and
  propagate, but **no carry-out**) plus one **carry-lookahead block** that computes all 4 carries
  at once.

So a CLA-row multiplier has **12 partial full adders + 3 carry-lookahead blocks**, instead of
12 full adders.

### How a 4-bit CLA works
For each bit `j` of a row (inputs `x_j` = partial-product bit, `y_j` = bit passed down):

```
g_j = x_j AND y_j      generate:  this bit makes a carry by itself
p_j = x_j XOR y_j      propagate: this bit passes an incoming carry on
s_j = p_j XOR c_j      sum
```

The lookahead block computes every carry directly from `g`, `p` and `c0`, without waiting
for the previous bit:

```
c1 = g0 + p0·c0
c2 = g1 + p1·g0 + p1·p0·c0
c3 = g2 + p2·g1 + p2·p1·g0 + p2·p1·p0·c0
c4 = g3 + p3·g2 + p3·p2·g1 + p3·p2·p1·g0 + p3·p2·p1·p0·c0
```

In this multiplier every row has `c0 = 0`, so all the `c0` terms disappear:

```
c1 = g0
c2 = g1 + p1·g0
c3 = g2 + p2·g1 + p2·p1·g0
c4 = g3 + p3·g2 + p3·p2·g1 + p3·p2·p1·g0
```

### What it gains and what it costs

| | Ripple-carry rows (assignment) | CLA rows |
|---|---|---|
| Adding cells | 12 full adders | 12 partial full adders + 3 lookahead blocks |
| Carry inside a row | ripples through up to 4 adders | about 2 gate levels for all carries |
| Row delay | grows with row width | roughly constant |
| Area | smaller | larger (the lookahead AND-OR terms grow quickly with width) |

### Why the speed-up is small here
1. **The rows are still in series.** Row 2 needs row 1's outputs, and row 3 needs row 2's.
   CLA speeds up the work *inside* each row but not the chain of 3 rows. The delay becomes
   roughly `t_AND + 3 × (t_pg + t_lookahead + t_sum)`.
2. **The ripple-row array already overlaps its rows.** The low bits of row `i+1` can start
   adding while the carry is still rippling through the high bits of row `i`. That is why
   the guide's estimate is about 2N full-adder delays, not N × N.
3. **4 bits is very short.** A 4-bit ripple chain is only 4 carry delays, so there is little to
   remove. CLA pays off for wide adders.

For a 4 × 4 multiplier, CLA rows give a modest speed-up for noticeably more area.

### Where CLA is actually used in multipliers
The standard design does not put a CLA in every row. Instead, it uses a **carry-save array**
or **Wallace/Dadda tree** to reduce all the partial products to two numbers without
propagating any carries, then adds those two numbers once with a **single fast adder** (CLA
or similar) at the bottom. That way the expensive carry propagation happens only once.
See section 2.

### For the assignment
- **You can't use CLA rows in `mult_array.v`.** The guide requires 12 `full_adder` instances
  wired as in its Section 2 table.
- **Synthesis blurs the difference anyway.** With `synth -flatten` and `abc`, Yosys flattens
  the full adders and rebuilds the logic from SKY130 cells, so the netlist won't contain
  12 neat full adders even though the RTL does. The critical path you see in Part C is
  whatever ABC built, not exactly the ripple chain you wrote.
- This is good material for report question 6.

---

## 4. Which parts of the assignment force the ripple-carry structure?

### Short answer
**Yes, the assignment forces it.** The required ripple-row structure is stated directly in the
guide, and several later steps and report questions assume it. A carry-lookahead (or any
other) adder in `mult_array.v` would break explicit requirements and make several answers
inconsistent. The tools themselves (Yosys, OpenSTA, LibreLane) would work fine with any design.

### Explicit requirements (breaking these costs marks directly)

| Where in the guide | What it requires |
|---|---|
| Section 5, file table | `rtl/mult_array.v` "must use **12 instances of `full_adder`** for the three adder rows" |
| Section 5, file table | `full_adder` has ports `a`, `b`, `cin`, `sum`, `cout`, "written with assign statements" |
| Section 5, intro | "Use exactly these file names, module names and port names, because the checking is done against them" |
| Section 2, "Exact connections" | "Use these equations to write mult_array.v": a ripple carry inside each row, `c_i[0] = 0`, and the exact bits passed down |
| Part A, task 2 | "Write rtl/mult_array.v following Sections 2 and 5" |

A CLA row has no full adders with a carry-out chain. It uses partial full adders plus a
lookahead block, so it cannot satisfy "12 instances of `full_adder`" wired as in Section 2.

### Later steps that assume the ripple-row structure

| Step | What it assumes | What goes wrong with a custom adder |
|---|---|---|
| Part A, task 6 (error test) | Changing `sum` in `full_adder.v` to `a ^ b` breaks all 12 adders | If the design doesn't use `full_adder` as specified, the test no longer checks what it is meant to check |
| Part A, block diagram | Shows "16 AND gates, 12 full adders and the registers" | A different design can't match the required diagram |
| Part C, task 3 | Count full-adder cells on the critical path and compare with "about 2N = 8 full-adder delays" | The 2N estimate applies only to the ripple-row array, so the comparison no longer makes sense |
| Report question 1 | "The array needs 16 AND gates and 12 full adders…" | The question's starting point would be wrong for your design |
| Report question 2 | Compare the critical path with "about 2N full-adder delays" | Same problem as Part C, task 3 |
| Report question 6 | "Using the formulas in Section 2", estimate the 8-bit version | The formulas (N(N − 1) full adders, about 2N delay) describe the ripple-row array only |

### Steps that don't care which adder you use
- **The 16 flip-flops and 2-cycle latency.** These come from the registers, not the adders.
- **The testbench.** It checks `p == a * b` for all 256 pairs, so any correct design passes.
- **Part B synthesis.** It works for any synthesizable RTL.
- **Part C STA and Part D LibreLane.** These run on whatever netlist they are given.

Also, `synth -flatten` followed by `abc` removes the full-adder boundaries and rebuilds the
logic from SKY130 cells. After synthesis, the difference between a ripple and a CLA version
in RTL may be much smaller than you'd expect, so the custom adder buys little in Parts B–D.

### The repository rules
- **Checking:** the guide says to use "exactly these file names, module names and port names,
  because the checking is done against them". A different adder structure fails the Section 5
  requirement that the checking is based on.
- **File structure:** the guide says to organise the repository "with exactly this structure".
  Adding extra design files (for example `rtl/mult_cla.v`) goes against that.
- **Understanding:** the academic integrity section requires you to be able to explain your
  implementation and approach. A design that doesn't match the guide invites questions about why.

### Safe way to explore a CLA (or other) version
1. Submit the required ripple-row design exactly as specified.
2. If you want to compare, build the CLA version in a separate folder **outside** the team
   repository and run it through the same synthesis and STA scripts.
3. Put the comparison (cell count, area, T_min) in the report as extra discussion, for example
   alongside question 6, clearly marked as beyond the required work.
4. If you want to submit a different structure, ask the instructor first.

---

## 5. What is RTL? Is it gate-level Verilog?

### Short answer
**No.** RTL (**Register-Transfer Level**) and gate level are two different levels of description,
and both can be written in Verilog. Verilog is the *language*; RTL and gate level are *how much
detail* you write in it.

- **RTL** describes a circuit as **registers** (flip-flops that hold values on clock edges) and
  the **logic that transfers data between them**, written as equations and operations. You say
  *what* each signal computes, not which physical gates compute it.
- **Gate level** (a *netlist*) describes the circuit as **instances of specific library cells**
  wired together, such as SKY130's `sky130_fd_sc_hd__xor3_1` or `sky130_fd_sc_hd__dfrtp_1`. You
  say exactly *which cells* are used and how they connect.

**Synthesis** (Yosys, Part B) is the step that converts RTL into a gate-level netlist.

### The name, piece by piece
- **Register:** the flip-flops. In `mult_array.v` these are `a_r`, `b_r` and `p` (16 flip-flops).
- **Transfer:** on each clock edge, data moves from one set of registers, through
  combinational logic, into the next set: `a_r, b_r → AND gates + full adders → p`.
- **Level:** a level of abstraction. RTL sits above gate level and below a purely behavioural
  description that has no clock-cycle timing.

### Same circuit, two levels (from this project)

RTL: `full_adder.v`, which you write:
```verilog
assign sum  = a ^ b ^ cin;
assign cout = (a & b) | (cin & (a ^ b));
```

Gate level: what Yosys + ABC produced from it using the SKY130 library:
```verilog
sky130_fd_sc_hd__xor3_1 _0_ (.A(b), .B(a), .C(cin), .X(sum));
sky130_fd_sc_hd__maj3_1 _1_ (.A(b), .B(a), .C(cin), .X(cout));
```

The synthesis tool chose a 3-input XOR cell for `sum` and a 3-input **majority** cell for `cout`.
A majority cell outputs 1 when at least two inputs are 1, which is exactly the carry function.
Nowhere does the RTL say "use a majority gate". That decision belongs to synthesis.

### The levels of abstraction

| Level | What you describe | Example | Who produces it in this assignment |
|---|---|---|---|
| Behavioural | what the result is, no clock structure | `p = a * b;` | not used (`*` is banned in `mult_array.v`) |
| **RTL** | registers + logic between them, clocked | `always @(posedge clk) p <= prod;` and `assign` equations | **you**: `rtl/full_adder.v`, `rtl/mult_array.v` |
| Gate level (netlist) | specific library cells and wires | `sky130_fd_sc_hd__maj3_1 _1_ (...)` | **Yosys**: `synth/mult_array_netlist.v` |
| Layout (physical) | shapes on each metal and silicon layer | polygons in a GDS file | **LibreLane**: `pnr/mult_array.gds` |

That table is the whole assignment title: **RTL → (synthesis) → gate level → (place and route)
→ GDSII**.

### Where `mult_array.v` sits
It is RTL, but written in a **structural** style:
- The registers and their reset are described in RTL `always` blocks.
- The full adders are **instantiated** as modules, which looks a lot like a netlist.

The difference is that `full_adder` is *your own* module described with equations, not a cell
from the SKY130 library. A true gate-level netlist contains only library cells. After
`synth -flatten`, your 12 `full_adder` instances disappear entirely and are replaced by SKY130
cells, which is why the netlist does not contain 12 neat full adders.

### Why the levels matter for the assignment
- **Part A** simulates the **RTL**. It checks that your *design* is correct.
- **Part B** simulates the **gate-level netlist** with the same testbench. It checks that
  *synthesis* did not change the behaviour. This is why that simulation needs the SKY130 cell
  models (`primitives.v`, `sky130_fd_sc_hd.v`): the netlist refers to cells that only exist
  in those files.
- **Part C** (static timing) runs on the gate-level netlist, because only real cells have
  known delays in the `.lib` file. RTL has no delays.

---

## 6. How do I run the testbench and GTKWave myself?

### Step 1: Open the tool environment (every new terminal)
```bash
cd ~/Desktop/DVD/DVD_Asgn
nix-shell tools/librelane/shell.nix     # prompt turns green: [nix-shell:...]
source env.sh
cd mult_2023102025_2023112010
```
`nix-shell` prints an error about `'nixpkgs' was not found` followed by `uses bash from your
environment`. It is harmless; all tools work.

If `nix-shell` itself is "not found", the terminal was opened before Nix was installed. Open a
new terminal, or run `. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`.

### Step 2: Compile and run the testbench (Part A, task 4)
Run these from the repository folder:
```bash
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim
```
- `iverilog` compiles the three files into a simulation program called `sim`.
  `-g2012` selects the Verilog-2012 language standard. **The testbench must come first** and
  `full_adder.v` must be included, or you get "Unknown module full_adder".
- `vvp` runs it. Expected output:
  ```
  VCD info: dumpfile mult.vcd opened for output.
  PASS: 256 vectors checked, 0 errors
  tb/tb_mult.v:77: $finish called at 7700000 (1ps)
  ```
- It also writes `mult.vcd` (the waveform). `sim` and `mult.vcd` are in `.gitignore`, so they are
  never committed.
- **Re-run both commands after any change** to a `.v` file. `vvp sim` alone runs the old
  compiled version.

### Step 3: Open the waveform in GTKWave
```bash
gtkwave mult.vcd &
```
The `&` keeps the terminal free.

1. **Add signals.** In the top-left *SST* panel, click `tb_mult`. The signals appear in the panel
   below it. Select `clk`, `rst_n`, `a`, `b` and `p` (Ctrl-click for several) and click
   **Append** (or drag them into the *Signals* panel).
   Use the signals under `tb_mult`, not the ones inside `dut`.
2. **Show values in decimal.** Select `a`, `b` and `p` in the *Signals* panel, right-click →
   **Data Format → Decimal**.
3. **Zoom.** **Zoom Fit** (magnifier icon with a box) shows the whole 7.7 µs run. To jump to a
   specific time, type it into the **From** and **To** boxes in the toolbar, for example
   From `5030 ns`, To `5070 ns`, and press Enter.
4. **Place markers.** Left-click in the waveform area to place the primary (red) marker. Its time
   appears at the top. To mark several points, use **Markers → Drop Named Marker** (letters A,
   B, C, …) at each point.
5. **Save your setup (optional).** **File → Write Save File** saves the signal list and formats
   to a `.gtkw` file. Next time, run `gtkwave mult.vcd mult.gtkw`. Keep it outside the
   repository (it is not in the required file structure), or add `*.gtkw` to `.gitignore`.

### Step 4: Find your example and mark the latency (Part A, task 5)
Vector number `k = a × 16 + b` is applied at `30 + 30k` ns:

| Example | Inputs applied (falling edge) | Edge 1: `a`, `b` captured | Edge 2: `p` updates |
|---|---|---|---|
| 10 × 7 (roll 2023102025) | 5040 ns | 5045 ns (`p` still 60) | **5055 ns, `p` = 70** |
| 5 × 7 (roll 2023112010) | 2640 ns | 2645 ns (`p` still 30) | **2655 ns, `p` = 35** |

For the screenshot:
- Zoom to roughly 10 ns before to 20 ns after the inputs change.
- Put named markers at the input change, edge 1 and edge 2.
- The **latency** is the two rising edges from the inputs being applied to `p` showing the
  new product. Annotate it with an arrow ("2 clock cycles") in any image editor if the markers
  alone aren't clear.
- `p` changes only at edge 2. After edge 1 it still shows the previous product, which is the
  best visual proof of the 2-cycle latency.

### Step 5: Prove the testbench catches errors (Part A, task 6)
**Commit `rtl/full_adder.v` first**, so Git can restore it afterwards:
```bash
# 1. Break the full adder
sed -i 's/assign sum  = a ^ b ^ cin;/assign sum  = a ^ b;/' rtl/full_adder.v
grep "assign sum" rtl/full_adder.v           # confirm: assign sum  = a ^ b;

# 2. Re-compile and run
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim                                      # expect MISMATCH lines, then:
                                             # FAIL: 256 vectors checked, 95 errors

# 3. Undo, and confirm it passes again
git checkout rtl/full_adder.v                # restores the committed version
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim                                      # PASS: 256 vectors checked, 0 errors
```
If the file isn't committed yet, `git checkout` cannot restore it. Undo by editing the line back
to `assign sum  = a ^ b ^ cin;` by hand.

Useful variants:
- `vvp sim | grep -E "^(PASS|FAIL)"` shows only the summary line.
- `vvp sim | head` shows the first few mismatches. Open the waveform at the first mismatch's time
  to debug.

### Common problems

| Symptom | Cause | Fix |
|---|---|---|
| `iverilog: command not found` | not inside the nix-shell | Step 1 |
| `Unknown module type: full_adder` | `rtl/full_adder.v` missing from the command | use the full command from Step 2 |
| Old results after editing | only ran `vvp sim` | re-run `iverilog` first |
| GTKWave shows old waveform | GTKWave doesn't reload automatically | **File → Reload Waveform** (Ctrl+Shift+R) |
| `a`, `b`, `p` shown as hex | default format | right-click → Data Format → Decimal |
| GTKWave doesn't open | started outside a graphical session | run it from a terminal in your desktop session |

---

## 7. How do I check that the Part C timing results are correct?

Run everything from the repository root, inside the nix-shell with `env.sh` sourced. Note that
every run of `sta/sta.tcl` overwrites `sta/mult_array_timing.rpt`; finish with a plain
`sta sta/sta.tcl` (T = 10 ns) so the committed report is restored.

### Check 1: Rerun and compare
```bash
sta sta/sta.tcl                 # worst slack max 7.017
T=2.98 sta sta/sta.tcl          # worst slack max -0.003
sta sta/sta.tcl                 # restore the T = 10 ns report
git diff sta/                   # no output = identical to the committed files
```

### Check 2: Redo the arithmetic from the report by hand
Open `sta/mult_array_timing.rpt` and find the path in **Path Group: clk** (the first path in the
file is the reset recovery check, in group `asynchronous`, which is not the setup path).

```
data arrival time   = 2.852 ns   (clock-to-Q 0.396 + 9 logic cells)
library setup time  = 0.131 ns   (the capture flip-flop needs D stable this long before the edge)
required time       = 10.000 - 0.131 = 9.869 ns
slack               = 9.869 - 2.852  = 7.017 ns        ✓ matches report_worst_slack

Tmin = arrival + setup = 2.852 + 0.131 = 2.983 ns   = 10 - 7.017   ✓
Fmax = 1000 / 2.983 = 335.2 MHz
```
Also add up the **Delay** column of the path yourself. It should give 2.852.

### Check 3: Slack must change one-for-one with the period
With an ideal clock, shortening the period by Δ reduces every setup slack by exactly Δ, and the
slack crosses 0 at T_min:

| T (ns) | Worst setup slack (ns) |
|---|---|
| 10.0 | 7.017 |
| 3.00 | 0.017 |
| 2.99 | 0.007 |
| **2.983** | **0.000** |
| 2.98 | −0.003 |
| 2.97 | −0.013 |

```bash
for t in 3.00 2.99 2.983 2.98 2.97; do echo -n "T=$t  "; T=$t sta sta/sta.tcl | grep "worst slack"; done
sta sta/sta.tcl     # restore the report
```
If the slack changed by anything other than Δ, the clock or the constraints would be wrong.

### Check 4: Nothing is unconstrained, and the other path types aren't limiting
STA only checks paths it knows about. A missing clock or delay would leave paths unchecked
and make F_max look better than it is. Make a scratch script, *not* in the repo (for example
`~/sta_check.tcl`), with the same first 7 lines as `sta.tcl` (period 2.98), then:
```tcl
check_setup -verbose                    ;# prints nothing if no unclocked/unconstrained/loop issues
puts [llength [all_registers -clock clk]]                                       ;# 16
report_checks -from [delete_from_list [all_inputs] [get_ports {clk rst_n}]] -format end
report_checks -to [all_outputs] -format end
report_worst_slack -min -digits 3       ;# hold check
exit
```
Expected at T = 2.98 ns:

| Check | Result | Meaning |
|---|---|---|
| `check_setup -verbose` | no output | no unclocked registers, unconstrained endpoints or combinational loops |
| registers on `clk` | 16 | all 16 flip-flops are timed |
| input → input register | slack 1.88 ns | not limiting |
| output register → output pin | slack 1.67 ns | not limiting |
| reset recovery | slack 2.208 ns | not limiting |
| hold (min) | slack 0.534 ns | no hold violations |

So the register-to-register path really is what sets T_min.

### Check 5: Does the path make sense for this design?
- **Start** `a_r[1]` and **end** `p[7]`: `p[7]` is the final carry `c3[4]`, the last output to
  settle. A path ending at a low bit like `p[0]` would be suspicious, because `p[0]` is a single AND gate.
- The path goes row 1 → row 2 → row 3, then ripples through all 4 carries of row 3 (3 `maj3`
  carry cells in a row), which is the ripple-row structure.
- 7 full adders on the path against the estimate of about 2N = 8 is the right order of size.

### Check 6: Optional independent cross-checks
- **Different tool:** OpenROAD contains the same timing engine. `openroad` accepts the same
  commands, so running `sta.tcl` in it should give identical numbers. It isn't independent, but
  it confirms the setup.
- **Synthesis sanity:** re-running `yosys -c synth/synth.tcl` must reproduce the committed
  netlist exactly (`git diff synth/` empty). Otherwise the STA was run on a different netlist.
