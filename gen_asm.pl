#!/usr/bin/perl

my $NREP = 4800;
my $NLOOP = 10000;

print <<EOT;
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#include <unistd.h>

#include "instbench.h"

EOT

sub prologue($) {
	print <<EOT;
void $_[0](tsc_count_t* tc)
{
	tc->count = $NREP * $NLOOP;
	uint64_t start, stop;

	read_cycle_counter(start);

	__asm__ __volatile__ (
	R"(
	.intel_syntax noprefix

	mov	rcx, $NLOOP
	rdtsc
	push rdx
	push rax
EOT
}

sub epilogue() {
	print <<EOT;
	sub	rcx, 1
	jnz	1b

	rdtsc
	pop	rcx
	sub	eax, ecx
	pop	rcx
	sbb	edx, ecx
	)"
		: /* no output */
		: /* no input */
		: "rax", "rbx", "rcx", "rdx", "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15");

	read_cycle_counter(stop);
	tc->tsc = stop - start;
}
EOT
}

# 生成するperl関数の命名規則は以下の通り
# gen_drr
# d : dst レジスタに依存関係が発生する命令。 add など
# n : dst レジスタに依存関係が発生しない命令。ほぼすべての vex prefix 命令や PMOVZXxx など
# rr : 汎用レジスタ2つ
# xx : xmm レジスタ2つ
#
# 生成されるC++関数の命名規則は以下の通り
# add_r64_tp
# tp : スループット計測
# lt1 : 最初の依存関係オペランドからのレイテンシ
# lt2 : 2番目の依存関係オペランドからのレイテンシ
# _2i : 2番目の依存関係オペランドに整数の定数を渡す

################ gen_drr ################

sub gen_drr($$) {
	my($inst, $label) = @_;

	prologue("$_[1]_tp");
	print <<EOT;
1:
.rept $NREP/10
	$inst	rax, rax
	$inst	rbx, rbx
	$inst	rdx, rdx
	$inst	r8, r8
	$inst	r9, r9
	$inst	r10, r10
	$inst	r11, r11
	$inst	r12, r12
	$inst	r13, r13
	$inst	r14, r14
.endr
EOT
	epilogue();

	prologue("$_[1]_lt1");
	print <<EOT;
1:
.rept $NREP
	$inst	rbx, rax
.endr
EOT
	epilogue();

	prologue("$_[1]_lt2");
	print <<EOT;
1:
.rept $NREP/10
	$inst	rbx, rax
	$inst	rdx, rbx
	$inst	r8, rdx
	$inst	r9, r8
	$inst	r10, r9
	$inst	r11, r10
	$inst	r12, r11
	$inst	r13, r12
	$inst	r14, r13
	$inst	rax, r14
.endr
EOT
	epilogue();
}

################ gen_nrr ################

sub gen_nrr($$) {
	my($inst, $label) = @_;

	prologue("$_[1]_tp");
	print <<EOT;
1:
.rept $NREP/10
	$inst	rax, rax
	$inst	rbx, rbx
	$inst	rdx, rdx
	$inst	r8, r8
	$inst	r9, r9
	$inst	r10, r10
	$inst	r11, r11
	$inst	r12, r12
	$inst	r13, r13
	$inst	r14, r14
.endr
EOT
	epilogue();

	prologue("$_[1]_lt1");
	print <<EOT;
1:
.rept $NREP/10
	$inst	rbx, rax
	$inst	rdx, rbx
	$inst	r8, rdx
	$inst	r9, r8
	$inst	r10, r9
	$inst	r11, r10
	$inst	r12, r11
	$inst	r13, r12
	$inst	r14, r13
	$inst	rax, r14
.endr
EOT
	epilogue();
}

################ gen_nrrr_2i ################

sub gen_nrrr_2i($$$) {
	my($inst, $label, $imm2) = @_;

	prologue("$_[1]_tp");
	print <<EOT;
	mov	r15, $imm2
1:
.rept $NREP/10
	$inst	rax, rax, r15
	$inst	rbx, rbx, r15
	$inst	rdx, rdx, r15
	$inst	r8, r8, r15
	$inst	r9, r9, r15
	$inst	r10, r10, r15
	$inst	r11, r11, r15
	$inst	r12, r12, r15
	$inst	r13, r13, r15
	$inst	r14, r14, r15
.endr
EOT
	epilogue();

	prologue("$_[1]_lt1");
	print <<EOT;
1:
.rept $NREP/10
	$inst	rbx, rax, r15
	$inst	rdx, rbx, r15
	$inst	r8, rdx, r15
	$inst	r9, r8, r15
	$inst	r10, r9, r15
	$inst	r11, r10, r15
	$inst	r12, r11, r15
	$inst	r13, r12, r15
	$inst	r14, r13, r15
	$inst	rax, r14, r15
.endr
EOT
	epilogue();
}

################ gen_nxx ################

sub gen_nxx($$) {
	my($inst, $label) = @_;

	prologue("$_[1]_tp");
	print <<EOT;
1:
.rept $NREP/10
	$inst	xmm0, xmm0
	$inst	xmm1, xmm1
	$inst	xmm2, xmm2
	$inst	xmm3, xmm3
	$inst	xmm4, xmm4
	$inst	xmm5, xmm5
	$inst	xmm6, xmm6
	$inst	xmm7, xmm7
	$inst	xmm8, xmm8
	$inst	xmm9, xmm9
.endr
EOT
	epilogue();

	prologue("$_[1]_lt1");
	print <<EOT;
1:
.rept $NREP/10
	$inst	xmm1, xmm0
	$inst	xmm2, xmm1
	$inst	xmm3, xmm2
	$inst	xmm4, xmm3
	$inst	xmm5, xmm4
	$inst	xmm6, xmm5
	$inst	xmm7, xmm6
	$inst	xmm8, xmm7
	$inst	xmm9, xmm8
	$inst	xmm0, xmm9
.endr
EOT
	epilogue();
}

################ gen_dxx ################

sub gen_dxx($$) {
	my($inst, $label) = @_;

	prologue("$_[1]_tp");
	print <<EOT;
1:
.rept $NREP/10
	$inst	xmm0, xmm0
	$inst	xmm1, xmm1
	$inst	xmm2, xmm2
	$inst	xmm3, xmm3
	$inst	xmm4, xmm4
	$inst	xmm5, xmm5
	$inst	xmm6, xmm6
	$inst	xmm7, xmm7
	$inst	xmm8, xmm8
	$inst	xmm9, xmm9
.endr
EOT
	epilogue();

	prologue("$_[1]_lt1");
	print <<EOT;
1:
.rept $NREP
	$inst	xmm1, xmm0
.endr
EOT
	epilogue();

	prologue("$_[1]_lt2");
	print <<EOT;
1:
.rept $NREP/10
	$inst	xmm1, xmm0
	$inst	xmm2, xmm1
	$inst	xmm3, xmm2
	$inst	xmm4, xmm3
	$inst	xmm5, xmm4
	$inst	xmm6, xmm5
	$inst	xmm7, xmm6
	$inst	xmm8, xmm7
	$inst	xmm9, xmm8
	$inst	xmm0, xmm9
.endr
EOT
	epilogue();
}

################ gen_nxxx ################

sub gen_nxxx($$) {
	my($inst, $label) = @_;

	prologue("$_[1]_tp");
	print <<EOT;
1:
.rept $NREP/10
	$inst	xmm0, xmm0, xmm15
	$inst	xmm1, xmm1, xmm15
	$inst	xmm2, xmm2, xmm15
	$inst	xmm3, xmm3, xmm15
	$inst	xmm4, xmm4, xmm15
	$inst	xmm5, xmm5, xmm15
	$inst	xmm6, xmm6, xmm15
	$inst	xmm7, xmm7, xmm15
	$inst	xmm8, xmm8, xmm15
	$inst	xmm9, xmm9, xmm15
.endr
EOT
	epilogue();

	prologue("$_[1]_lt1");
	print <<EOT;
1:
.rept $NREP
	$inst	xmm0, xmm0, xmm15
.endr
EOT
	epilogue();

	prologue("$_[1]_lt2");
	print <<EOT;
1:
.rept $NREP/10
	$inst	xmm1, xmm0, xmm15
	$inst	xmm2, xmm1, xmm15
	$inst	xmm3, xmm2, xmm15
	$inst	xmm4, xmm3, xmm15
	$inst	xmm5, xmm4, xmm15
	$inst	xmm6, xmm5, xmm15
	$inst	xmm7, xmm6, xmm15
	$inst	xmm8, xmm7, xmm15
	$inst	xmm9, xmm8, xmm15
	$inst	xmm0, xmm9, xmm15
.endr
EOT
	epilogue();
}

################ gen_nxxxx ################

sub gen_nxxxx($$) {
	my($inst, $label) = @_;

	prologue("$_[1]_tp");
	print <<EOT;
1:
.rept $NREP/10
	$inst	xmm0, xmm15, xmm15, xmm15
	$inst	xmm1, xmm15, xmm15, xmm15
	$inst	xmm2, xmm15, xmm15, xmm15
	$inst	xmm3, xmm15, xmm15, xmm15
	$inst	xmm4, xmm15, xmm15, xmm15
	$inst	xmm5, xmm15, xmm15, xmm15
	$inst	xmm6, xmm15, xmm15, xmm15
	$inst	xmm7, xmm15, xmm15, xmm15
	$inst	xmm8, xmm15, xmm15, xmm15
	$inst	xmm9, xmm15, xmm15, xmm15
.endr
EOT
	epilogue();

	prologue("$_[1]_lt1");
	print <<EOT;
1:
.rept $NREP/10
	$inst	xmm1, xmm0, xmm15, xmm15
	$inst	xmm2, xmm1, xmm15, xmm15
	$inst	xmm3, xmm2, xmm15, xmm15
	$inst	xmm4, xmm3, xmm15, xmm15
	$inst	xmm5, xmm4, xmm15, xmm15
	$inst	xmm6, xmm5, xmm15, xmm15
	$inst	xmm7, xmm6, xmm15, xmm15
	$inst	xmm8, xmm7, xmm15, xmm15
	$inst	xmm9, xmm8, xmm15, xmm15
	$inst	xmm0, xmm9, xmm15, xmm15
.endr
EOT
	epilogue();

	prologue("$_[1]_lt2");
	print <<EOT;
1:
.rept $NREP/10
	$inst	xmm1, xmm15, xmm0, xmm15
	$inst	xmm2, xmm15, xmm1, xmm15
	$inst	xmm3, xmm15, xmm2, xmm15
	$inst	xmm4, xmm15, xmm3, xmm15
	$inst	xmm5, xmm15, xmm4, xmm15
	$inst	xmm6, xmm15, xmm5, xmm15
	$inst	xmm7, xmm15, xmm6, xmm15
	$inst	xmm8, xmm15, xmm7, xmm15
	$inst	xmm9, xmm15, xmm8, xmm15
	$inst	xmm0, xmm15, xmm9, xmm15
.endr
EOT
	epilogue();

	prologue("$_[1]_lt3");
	print <<EOT;
1:
.rept $NREP/10
	$inst	xmm1, xmm15, xmm15, xmm0
	$inst	xmm2, xmm15, xmm15, xmm1
	$inst	xmm3, xmm15, xmm15, xmm2
	$inst	xmm4, xmm15, xmm15, xmm3
	$inst	xmm5, xmm15, xmm15, xmm4
	$inst	xmm6, xmm15, xmm15, xmm5
	$inst	xmm7, xmm15, xmm15, xmm6
	$inst	xmm8, xmm15, xmm15, xmm7
	$inst	xmm9, xmm15, xmm15, xmm8
	$inst	xmm0, xmm15, xmm15, xmm9
.endr
EOT
	epilogue();
}

################ gen_nyy ################

sub gen_nyy($$) {
	my($inst, $label) = @_;

	prologue("$_[1]_tp");
	print <<EOT;
1:
.rept $NREP/10
	$inst	ymm0, ymm0
	$inst	ymm1, ymm1
	$inst	ymm2, ymm2
	$inst	ymm3, ymm3
	$inst	ymm4, ymm4
	$inst	ymm5, ymm5
	$inst	ymm6, ymm6
	$inst	ymm7, ymm7
	$inst	ymm8, ymm8
	$inst	ymm9, ymm9
.endr
EOT
	epilogue();

	prologue("$_[1]_lt1");
	print <<EOT;
1:
.rept $NREP
	$inst	ymm0, ymm0
.endr
EOT
	epilogue();
}

################ gen_nyx ################

sub gen_nyx($$) {
	my($inst, $label) = @_;

	prologue("$_[1]_tp");
	print <<EOT;
1:
.rept $NREP/10
	$inst	ymm0, xmm0
	$inst	ymm1, xmm1
	$inst	ymm2, xmm2
	$inst	ymm3, xmm3
	$inst	ymm4, xmm4
	$inst	ymm5, xmm5
	$inst	ymm6, xmm6
	$inst	ymm7, xmm7
	$inst	ymm8, xmm8
	$inst	ymm9, xmm9
.endr
EOT
	epilogue();

	prologue("$_[1]_lt1");
	print <<EOT;
1:
.rept $NREP
	$inst	ymm0, xmm0
.endr
EOT
	epilogue();
}

################ gen_nyyy ################

sub gen_nyyy($$) {
	my($inst, $label) = @_;

	prologue("$_[1]_tp");
	print <<EOT;
1:
.rept $NREP/10
	$inst	ymm0, ymm0, ymm15
	$inst	ymm1, ymm1, ymm15
	$inst	ymm2, ymm2, ymm15
	$inst	ymm3, ymm3, ymm15
	$inst	ymm4, ymm4, ymm15
	$inst	ymm5, ymm5, ymm15
	$inst	ymm6, ymm6, ymm15
	$inst	ymm7, ymm7, ymm15
	$inst	ymm8, ymm8, ymm15
	$inst	ymm9, ymm9, ymm15
.endr
EOT
	epilogue();

	prologue("$_[1]_lt1");
	print <<EOT;
1:
.rept $NREP
	$inst	ymm0, ymm0, ymm15
.endr
EOT
	epilogue();

	prologue("$_[1]_lt2");
	print <<EOT;
1:
.rept $NREP/10
	$inst	ymm1, ymm0, ymm15
	$inst	ymm2, ymm1, ymm15
	$inst	ymm3, ymm2, ymm15
	$inst	ymm4, ymm3, ymm15
	$inst	ymm5, ymm4, ymm15
	$inst	ymm6, ymm5, ymm15
	$inst	ymm7, ymm6, ymm15
	$inst	ymm8, ymm7, ymm15
	$inst	ymm9, ymm8, ymm15
	$inst	ymm0, ymm9, ymm15
.endr
EOT
	epilogue();
}

gen_drr("add", "add_r64");
gen_dxx("paddb", "paddb_xmm");
gen_nxxx("vpaddb", "vpaddb_xmm");
gen_nxx("pmovzxbw", "pmovzxbw_xmm");
gen_nyx("vpmovzxbw", "vpmovzxbw_ymm");
gen_nxxxx("vpblendvb", "vpblendvb_xmm");
gen_nrrr_2i("pext", "pext_all0", "0x0000000000000000");
gen_nrrr_2i("pext", "pext_all1", "0xffffffffffffffff");
gen_nrrr_2i("pext", "pext_half", "0x5555555555555555");
gen_nrrr_2i("pext", "pext_lo",   "0x00000000ffffffff");
gen_nrrr_2i("pext", "pext_hi",   "0xffffffff00000000");
