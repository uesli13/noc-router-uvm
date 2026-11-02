# RTL mutations

Mutations used to check that the scoreboard catches the errors it was written for.
Each one adds a small bug to the RTL inside an `ifdef MUT_<NAME>`, so the design is
unchanged when no mutation is selected.

The mutations are kept as a patch (`rtl_mutations.patch`) on top of DUT_Design commit
`9a2fc94`, so the submodule itself stays on the designer's RTL.

## Usage

```bash
cd DUT_Design
git checkout 9a2fc94
git apply ../verif/mutations/rtl_mutations.patch

cd ../verif/sim
make run TESTNAME=router_packet_test MUT=MUT_SB_DATA

# remove the patch
cd ../../DUT_Design
git restore RTL
```

## Mutations

DUT at (1,1).

| Mutation | File | Change | Test | Expected errors |
|---|---|---|---|---|
| MUT_SB_DATA | crossbar.sv | flip payload bit 0 of BODY flits | router_packet_test | 2 x SB_DATA |
| MUT_SB_LEFTOVER | router.sv | no is_valid for TAIL on WEST | router_packet_test | SB_LEFTOVER (3/4) |
| MUT_SB_VC | vc_allocator.sv | ESCAPE packets get only ADAPTIVE VCs | router_packet_test | SB_VC |
| MUT_SB_ROUTE_XY | rc_unit.sv | YX instead of XY | router_sanity_test +VC=ESCAPE | SB_ROUTE |
| MUT_SB_ROUTE_ADAPT | rc_unit.sv | WEST replaced by EAST in adaptive set | router_sanity_test +YD=1 | SB_ROUTE |
| MUT_SB_NOMATCH_HEAD | crossbar.sv | flip payload bit 0 of HEAD flits | router_sanity_test | SB_NOMATCH, SB_LEFTOVER |
| MUT_SB_NOMATCH_BT | crossbar.sv | HEAD -> BODY, HEADTAIL -> TAIL | router_sanity_test | SB_NOMATCH, SB_LEFTOVER |
| MUT_SB_EXTRA | circular_buffer.sv | first BODY flit is read twice | router_packet_test | 2 x SB_DATA, SB_EXTRA, CRED_OVF |
| MUT_SB_INTERLEAVE | vc_allocator.sv | allocated VC not marked as busy | router_contention_test | SB_INTERLEAVE + more |

Tests options go in `PLUSARGS`, e.g. `PLUSARGS="+VC=ESCAPE"`.

The two ROUTE mutations are not caught with every destination (e.g. MUT_SB_ROUTE_XY with
+YD=1 passes), because the wrong and the right port can be the same.

## SB_IN_PROTO

These two checks need illegal stimulus, not RTL changes:

- `router_no_head_packet_test`: packet without HEAD
- `router_no_tail_packet_test`: packets without TAIL

## Updating the patch

Mutations are edited on the `mutations` branch of my fork
(https://github.com/uesli13/2.5D-Network-on-Chip-Router-in-SystemVerilog). Then:

```bash
cd DUT_Design
git diff 9a2fc94 mutations -- RTL > ../verif/mutations/rtl_mutations.patch
```