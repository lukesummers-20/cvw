// coverage.svh
// David_Harris@hmc.edu 7 September 2024
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// This file is needed in the config subdirectory for each config supporting coverage.
// It defines which extensions are enabled for that config.

`define COVER_RV64I
`define COVER_RV64M
`define COVER_RV64F
`include "coverage/RV64I_coverage.svh"
`include "coverage/RV64M_coverage.svh"
`include "coverage/RV64F_coverage.svh"
