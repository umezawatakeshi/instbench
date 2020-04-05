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
EOT
}

sub epilogue() {
	print <<EOT;
	sub	rcx, 1
	jnz	1b
	)"
		: /* no output */
		: /* no input */
		: "rax", "rbx", "rcx", "rdx", "rsi", "rdi", "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15");

	read_cycle_counter(stop);
	tc->tsc = stop - start;
}
EOT
}

sub gen($$$;$) {
	my($fn, $n, $body, $pre) = @_;

	$pre = "" unless defined($pre);

	prologue($fn);
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
# gen_n3_c3
# d : dst レジスタに依存関係が発生する命令。 add など
# n : dst レジスタに依存関係が発生しない命令。ほぼすべての vex prefix 命令や PMOVZXxx など
# 3 : オペランドが3つ
# c3 : 3番目のオペランドに定数を指定（BSR や PEXT など値によって速度が変わる命令で使う）
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
