#!/usr/bin/perl

use Data::Dumper;
use YAML qw(LoadFile);
use File::Find;

use strict;

$|++;

use FindBin qw($Bin);

#use lib ".";

# usage : perl gen_protobuf_cs.pl ProjectPath

my ($destPath) = (@ARGV);

if (!$destPath)
{
	&usage();
}

# load configuration
my $configHash = LoadFile($destPath . "/config.yml");

my $PROTOC_CMD = "$Bin/../ProtoGen/protoc";
my $PROTOGEN_CMD = "$Bin/../ProtoGen/protogen";

my $protobufDefinePath = "$destPath/" . $configHash->{"projectName"} . "_ProtobufDefine";
my $protobufTempPath = "$destPath/" . $configHash->{"projectName"} . "_ProtobufTemp";

if (!-e $protobufTempPath){
	mkdir($protobufTempPath);
}

my $protobufClassesPath = "$destPath/" . $configHash->{"projectName"} . "_Client/Assets/Scripts/ProtobufClasses";

if (!-e $protobufClassesPath){
	mkdir($protobufClassesPath);
}

find({ wanted => \&process, no_chdir => 0}, $protobufDefinePath);

sub process{
	my $filePath = $File::Find::name;
	my $fileName = $_;
	
	if (-d $fileName){
		return;
	}
	
	my $outputPath = $protobufTempPath . "/" . $fileName . ".bin";
	
	my $status;
	
	print "$PROTOC_CMD -I$protobufDefinePath $filePath -o$outputPath" . "\n";
	
	$status = system("$PROTOC_CMD -I$protobufDefinePath $filePath -o$outputPath");
	if ($status){
		die "protoc生成出错 $!\n";
	}
	
	my $csPath = $protobufClassesPath . "/" . $_ . ".cs";
	print $PROTOGEN_CMD . " -i:$outputPath -o:$csPath -q" . "\n";
	$status = system($PROTOGEN_CMD . " -i:$outputPath -o:$csPath -q");
	if ($status){
		die "生成cs类出错\n";
	}
}
