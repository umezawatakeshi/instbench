#!/usr/bin/perl

my $NREP = 240;
my $NLOOP = 10000;

print <<EOT;
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#include <unistd.h>

#include "instbench.h"

EOT

sub prologue($$) {
	print <<EOT;
void $_[0](tsc_count_t* tc)
{
	tc->count = $NREP * $NLOOP;
	uint64_t start, stop;
	void* dummy;

	$_[1]

	read_cycle_counter(start);

	__asm__ __volatile__ (
	R"(
	.intel_syntax noprefix

	mov	rcx, $NLOOP
EOT
}

sub epilogue() {
	print <<EOT;
	sub	rcx, 1
	jnz	1b
	)"
		: "=a"(dummy)
		: "a"(tmpbuf)
		: "rbx", "rcx", "rdx", "rsi", "rdi", "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15");

	read_cycle_counter(stop);
	tc->tsc = stop - start;
}
EOT
}

sub gen($$$;$$) {
	my($fn, $n, $body, $pre, $precxx) = @_;

	$pre = "" unless defined($pre);
	$precxx = "" unless defined($precxx);

	prologue($fn, $precxx);
	print <<EOT;
$pre
1:
.rept $NREP/$n
$body
.endr
EOT
	epilogue();
}


sub gen_regs($) {
	my @ret = ();

	for (my $i = 0; $i < 10; ++$i) {
		push(@ret, "$_[0]$i");
	}
	for (my $i = 13; $i <= 15; ++$i) {
		push(@ret, "$_[0]$i");
	}

	return \@ret;
}

my $r64 = [ "rax", "rbx", "rdx", "rsi", "rdi", "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15" ];
my $xmm = gen_regs("xmm");
my $ymm = gen_regs("ymm");
my $zmm = gen_regs("zmm");


# 生成するperl関数の命名規則は以下の通り
# gen_n3_c3 genz_n2_k
# m : AVX-512 において、merging-masking を使う
# z : AVX-512 において、zeroing-masking を使う
# d : dst レジスタに依存関係が発生する命令。 add など
# n : dst レジスタに依存関係が発生しない命令。ほぼすべての vex prefix 命令や PMOVZXxx など
# 3 : オペランドが3つ
# c3 : 3番目のオペランドに定数を指定（BSR や PEXT など値によって速度が変わる命令で使う）
# k : masking に使う k レジスタに定数を指定
#
# 生成されるC++関数の命名規則は以下の通り
# add_r64_tp
# tp : スループット計測
# lt1 : 最初の依存関係オペランドからのレイテンシ
# lt2 : 2番目の依存関係オペランドからのレイテンシ


################ gen_d2 ################

sub gen_d2($$$$) {
	my($inst, $label, $o1, $o2) = @_;

	gen("$_[1]_tp", 10, join("\n", map { "$inst $o1->[$_], $o2->[-1]" } 0..9));
	gen("$_[1]_lt1", 1, "$inst $o1->[0], $o2->[-1]");
	gen("$_[1]_lt2", 10, join("\n", map { "$inst $o1->[($_+1)%10], $o2->[$_]" } 0..9));
}

################ gen_d3 ################

sub gen_d3($$$$$) {
	my($inst, $label, $o1, $o2, $o3) = @_;

	gen("$_[1]_tp", 10, join("\n", map { "$inst $o1->[$_], $o2->[-2], $o3->[-1]" } 0..9));
	gen("$_[1]_lt1", 1, "$inst $o1->[0], $o2->[-2], $o3->[-1]");
	gen("$_[1]_lt2", 10, join("\n", map { "$inst $o1->[($_+1)%10], $o2->[$_], $o3->[-1]" } 0..9));
	gen("$_[1]_lt3", 10, join("\n", map { "$inst $o1->[($_+1)%10], $o2->[-1], $o3->[$_]" } 0..9));
}

################ gen_n2 ################

sub gen_n2($$$$) {
	my($inst, $label, $o1, $o2) = @_;

	gen("$_[1]_tp", 1, "$inst $o1->[0], $o2->[-1]");
	gen("$_[1]_lt1", 1, "$inst $o1->[0], $o2->[0]");
}

################ gen_n3 ################

sub gen_n3($$$$$) {
	my($inst, $label, $o1, $o2, $o3) = @_;

	gen("$_[1]_tp", 1, "$inst $o1->[0], $o2->[-2], $o3->[-1]");
	gen("$_[1]_lt1", 1, "$inst $o1->[0], $o2->[0], $o3->[-1]");
	gen("$_[1]_lt2", 1, "$inst $o1->[0], $o2->[-1], $o3->[0]");
}

################ gen_n4 ################

sub gen_n4($$$$$$) {
	my($inst, $label, $o1, $o2, $o3, $o4) = @_;

	gen("$_[1]_tp", 1, "$inst $o1->[0], $o2->[-3], $o3->[-2], $o4->[-1]");
	gen("$_[1]_lt1", 1, "$inst $o1->[0], $o2->[0], $o3->[-2], $o4->[-1]");
	gen("$_[1]_lt2", 1, "$inst $o1->[0], $o2->[-2], $o3->[0], $o4->[-1]");
	gen("$_[1]_lt3", 1, "$inst $o1->[0], $o2->[-2], $o3->[-1], $o4->[0]");
}

################ gen_n3_c3 ################

sub gen_n3_c3($$$$$$) {
	my($inst, $label, $o1, $o2, $o3, $c3) = @_;

	my $pre = "mov $o3->[-1], $c3";
	gen("$_[1]_tp", 1, "$inst $o1->[0], $o2->[-2], $o3->[-1]", $pre);
	gen("$_[1]_lt1", 1, "$inst $o1->[0], $o2->[0], $o3->[-1]", $pre);
}

################ genz_n2_k ################

sub genz_n2_k($$$$$) {
	my($inst, $label, $o1, $o2, $k) = @_;

	my $pre = "mov rax, $k \n kmovq k7, rax";
	gen("$_[1]_tp", 1, "$inst $o1->[0]\%{k7}%{z}, $o2->[-1]", $pre);
	gen("$_[1]_lt1", 1, "$inst $o1->[0]\%{k7}%{z}, $o2->[0]", $pre);
}

################ genm_vpgather_k0 ################

sub genm_vpgather_k0($$$$) {
	my($inst, $label, $o1, $o2) = @_;

	my $pre = "mov rax, 0 \n" . join("\n", map { "kmovq k$_, rax" } 1..5);
	gen("$_[1]_tp", 5, join("\n", map { "$inst $o1->[$_]\%{k$_}, \[rax + $o2->[-1]]" } 1..5), $pre);
	gen("$_[1]_lt1", 5, join("\n", map { "$inst $o1->[0]\%{k$_}, \[rax + $o2->[-1]]" } 1..5), $pre);
	gen("$_[1]_lt2", 5, join("\n", map { "$inst $o1->[$_]\%{k1}, \[rax + $o2->[-1]]" } 1..5), $pre);
	gen("$_[1]_lt3", 5, join("\n", map { "$inst $o1->[$_%5+1]\%{k$_}, \[rax + $o2->[$_]]" } 1..5), $pre);
}

################ genm_vpgather_k ################

sub genm_vpgather_k($$$$$$) {
	my($inst, $label, $o1, $o2, $t, $k) = @_;

	my $precxx = <<EOCXX;
	$t* p = ($t*)tmpbuf;
	for (int i = 0; i < 64; ++i) {
		p[i] = sizeof($t) * i;
	}
EOCXX
	my $pre = "mov rbx, $k \n kmovq k7, rbx \n" . join("\n", map { "vmovdqu32 $o1->[$_], \[rax]" } 1..5);
	gen("$_[1]_tp", 5, join("\n", map { "kmovd k$_, k7 \n $inst $o1->[$_]\%{k$_}, \[rax + $o2->[-1]]" } 1..5), $pre, $precxx);
	gen("$_[1]_lt1", 5, join("\n", map { "kmovd k$_, k7 \n $inst $o1->[0]\%{k$_}, \[rax + $o2->[-1]]" } 1..5), $pre, $precxx);
	gen("$_[1]_lt2", 5, join("\n", map { "kmovd k1, k7 \n $inst $o1->[$_]\%{k1}, \[rax + $o2->[-1]]" } 1..5), $pre, $precxx);
	gen("$_[1]_lt3", 5, join("\n", map { "kmovd k$_, k7 \n $inst $o1->[$_%5+1]\%{k$_}, \[rax + $o2->[$_]]" } 1..5), $pre, $precxx);
}

################ genm_vpscatter_k ################

sub genm_vpscatter_k($$$$$$) {
	my($inst, $label, $o1, $o2, $t, $k) = @_;

	my $precxx = <<EOCXX;
	$t* p = ($t*)tmpbuf;
	for (int i = 0; i < 64; ++i) {
		p[i] = sizeof($t) * i;
	}
EOCXX
	my $pre = "mov rbx, $k \n kmovq k7, rbx \n vmovdqu32 $o1->[-1], \[rax]";
	gen("$_[1]_tp", 1, "kmovd k1, k7 \n $inst \[rax + $o1->[-1]]\%{k1}, $o2->[-2]", $pre, $precxx);
}

################################

gen_d2("add", "add_r64", $r64, $r64);
gen_d2("paddb", "paddb_xmm", $xmm, $xmm);
gen_n3("vpaddb", "vpaddb_xmm", $xmm, $xmm, $xmm);
gen_n2("pmovzxbw", "pmovzxbw_xmm", $xmm, $xmm);
gen_n2("vpmovzxbw", "vpmovzxbw_ymm", $ymm, $xmm);
gen_n4("vpblendvb", "vpblendvb_xmm", $xmm, $xmm, $xmm, $xmm);
gen_n3_c3("pext", "pext_all0", $r64, $r64, $r64, "0x0000000000000000");
gen_n3_c3("pext", "pext_all1", $r64, $r64, $r64, "0xffffffffffffffff");
gen_n3_c3("pext", "pext_half", $r64, $r64, $r64, "0x5555555555555555");
gen_n3_c3("pext", "pext_lo",   $r64, $r64, $r64, "0x00000000ffffffff");
gen_n3_c3("pext", "pext_hi",   $r64, $r64, $r64, "0xffffffff00000000");
gen_n3("vpermb", "vpermb_xmm", $xmm, $xmm, $xmm);
gen_n3("vpermb", "vpermb_zmm", $zmm, $zmm, $zmm);
gen_n3("vpermw", "vpermw_zmm", $zmm, $zmm, $zmm);
gen_n3("vpermd", "vpermd_zmm", $zmm, $zmm, $zmm);
gen_n3("vpermq", "vpermq_zmm", $zmm, $zmm, $zmm);
gen_d3("vpermt2b", "vpermt2b_xmm", $xmm, $xmm, $xmm);
gen_d3("vpermt2b", "vpermt2b_zmm", $zmm, $zmm, $zmm);
gen_d3("vpermt2w", "vpermt2w_zmm", $zmm, $zmm, $zmm);
gen_d3("vpermt2d", "vpermt2d_zmm", $zmm, $zmm, $zmm);
gen_d3("vpermt2q", "vpermt2q_zmm", $zmm, $zmm, $zmm);
gen_d3("vpermi2b", "vpermi2b_zmm", $zmm, $zmm, $zmm);
gen_d3("vpermi2w", "vpermi2w_zmm", $zmm, $zmm, $zmm);
gen_d3("vpermi2d", "vpermi2d_zmm", $zmm, $zmm, $zmm);
gen_d3("vpermi2q", "vpermi2q_zmm", $zmm, $zmm, $zmm);
genz_n2_k("vpcompressb", "vpcompressb_xmm_all0", $xmm, $xmm, "0x0000");
genz_n2_k("vpcompressb", "vpcompressb_zmm_all0", $zmm, $zmm, "0x0000000000000000");
genz_n2_k("vpcompressb", "vpcompressb_xmm_all1", $xmm, $xmm, "0xffff");
genz_n2_k("vpcompressb", "vpcompressb_zmm_all1", $zmm, $zmm, "0xffffffffffffffff");
genz_n2_k("vpcompressb", "vpcompressb_xmm_half", $xmm, $xmm, "0x5555");
genz_n2_k("vpcompressb", "vpcompressb_zmm_half", $zmm, $zmm, "0x5555555555555555");
genz_n2_k("vpcompressw", "vpcompressw_zmm_half", $zmm, $zmm, "0x55555555");
genz_n2_k("vpcompressd", "vpcompressd_zmm_half", $zmm, $zmm, "0x5555");
genz_n2_k("vpcompressq", "vpcompressq_zmm_half", $zmm, $zmm, "0x55");
genm_vpgather_k0("vpgatherdd", "vpgatherdd_zmm_k0", $zmm, $zmm);
genm_vpgather_k0("vpgatherqq", "vpgatherqq_zmm_k0", $zmm, $zmm);
genm_vpgather_k0("vpgatherqq", "vpgatherqq_ymm_k0", $ymm, $ymm);
genm_vpgather_k0("vpgatherqq", "vpgatherqq_xmm_k0", $xmm, $xmm);
genm_vpgather_k("vpgatherdd", "vpgatherdd_zmm_all1", $zmm, $zmm, "uint32_t", "0xffff");
genm_vpgather_k("vpgatherqq", "vpgatherqq_zmm_all1", $zmm, $zmm, "uint64_t", "0xff");
genm_vpscatter_k("vpscatterdd", "vpscatterdd_zmm_all0", $zmm, $zmm, "uint32_t", "0x0000");
genm_vpscatter_k("vpscatterqq", "vpscatterqq_zmm_all0", $zmm, $zmm, "uint64_t", "0x00");
genm_vpscatter_k("vpscatterdd", "vpscatterdd_zmm_all1", $zmm, $zmm, "uint32_t", "0xffff");
genm_vpscatter_k("vpscatterqq", "vpscatterqq_zmm_all1", $zmm, $zmm, "uint64_t", "0xff");
gen_d3("vpdpwssd", "vpdpwssd_xmm", $xmm, $xmm, $xmm);
gen_d3("vpdpwssd", "vpdpwssd_ymm", $ymm, $ymm, $ymm);
gen_d3("vpdpwssd", "vpdpwssd_zmm", $zmm, $zmm, $zmm);
gen_n3("vpmaddwd", "vpmaddwd_xmm", $xmm, $xmm, $xmm);
gen_n3("vpmaddwd", "vpmaddwd_ymm", $ymm, $ymm, $ymm);
gen_n3("vpmaddwd", "vpmaddwd_zmm", $zmm, $zmm, $zmm);
gen_n3("vpmultishiftqb", "vpmultishiftqb_xmm", $xmm, $xmm, $xmm);
gen_n3("vpmultishiftqb", "vpmultishiftqb_ymm", $ymm, $ymm, $ymm);
gen_n3("vpmultishiftqb", "vpmultishiftqb_zmm", $zmm, $zmm, $zmm);
