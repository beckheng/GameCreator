#!/usr/bin/perl

# convert .proto to .cs files

use Data::Dumper;
use YAML qw(LoadFile);
use File::Find;
use File::Path qw(make_path);

use strict;

$|++;

use FindBin qw($Bin);

use lib "$Bin/perlib";

use LogUtil;

# usage : perl gen_protobuf_cs.pl ProjectPath

my ($destPath) = (@ARGV);

if (!$destPath)
{
	die "usage: perl $0 ProjectPath\n";
}

# load configuration
my $configHash = LoadFile($destPath . "/config.yml");

my $PROTOC_CMD = "$Bin/../ProtoGen/protoc";
my $PROTOGEN_CMD = "$Bin/../ProtoGen/protogen";

my $protobufDefinePath = "$destPath/" . $configHash->{"projectName"} . "_ProtobufDefine";
my $protobufExcelPath = "$destPath/" . $configHash->{"projectName"} . "_tmp/ProtobufExcel";

my $protobufTempPath = "$destPath/" . $configHash->{"projectName"} . "_tmp/ProtobufTemp";

if (!-e $protobufTempPath){
	make_path($protobufTempPath);
}

my $protobufClassesPath = "$destPath/" . $configHash->{"projectName"} . "_Client/Assets/Standard Assets/ProtobufClasses";

if (!-e $protobufClassesPath){
	make_path($protobufClassesPath);
}

find({ wanted => \&process, no_chdir => 0}, $protobufDefinePath);
find({ wanted => \&processExcel, no_chdir => 0}, $protobufExcelPath);

sub process{
	my $filePath = $File::Find::name;
	my $fileDir = $File::Find::dir;
	my $fileName = $_;
	
	if (-d $fileName){
		return;
	}
	
	my $basename = $fileName;
	$basename =~ s/.proto$//g;
	
	my $outputPath = $protobufTempPath . "/" . $fileName . ".bin";
	
	my $status;
	
	LogUtil::LogDebug("$PROTOC_CMD -I$fileDir $filePath -o$outputPath");
	
	$status = system("$PROTOC_CMD -I$fileDir $filePath -o$outputPath");
	if ($status){
		die "protoc生成出错 $!\n";
	}
	
	my $csDir = $protobufClassesPath . "/" . $basename;
	if (!-e $csDir){
		mkdir($csDir);
	}
	
	my $csPath = $csDir . "/" . $_ . ".cs";
	LogUtil::LogDebug($PROTOGEN_CMD . " -i:$outputPath -o:$csPath -q -ns:KData");
	$status = system($PROTOGEN_CMD . " -i:$outputPath -o:\"$csPath\" -q -ns:KData");
	if ($status){
		die "生成cs类出错\n";
	}
}

sub processExcel{
	my $filePath = $File::Find::name;
	my $fileDir = $File::Find::dir;
	my $fileName = $_;
	
	if (-d $fileName){
		return;
	}
	
	my $basename = $fileName;
	$basename =~ s/.proto$//g;
	
	my $outputPath = $protobufTempPath . "/" . $fileName . ".bin";
	
	my $status;
	
	LogUtil::LogDebug("$PROTOC_CMD -I$fileDir $filePath -o$outputPath");
	
	$status = system("$PROTOC_CMD -I$fileDir $filePath -o$outputPath");
	if ($status){
		die "protoc生成出错 $!\n";
	}
	
	my $csDir = $protobufClassesPath . "/" . $basename;
	if (!-e $csDir){
		mkdir($csDir);
	}

	my $csPath = $csDir . "/" . $_ . ".cs";
	LogUtil::LogDebug($PROTOGEN_CMD . " -i:$outputPath -o:$csPath -q -ns:KData");
	$status = system($PROTOGEN_CMD . " -i:$outputPath -o:\"$csPath\" -q -ns:KData");
	if ($status){
		die "生成cs类出错\n";
	}
}
