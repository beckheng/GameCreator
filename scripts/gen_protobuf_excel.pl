#!/usr/bin/perl

# convert excel to .proto files

use Data::Dumper;
use YAML qw(LoadFile);
use File::Find;
use Spreadsheet::BasicRead;

use strict;

$|++;

use FindBin qw($Bin);

use lib "$Bin/perlib";

use LogUtil;

# usage : perl gen_protobuf_excel.pl ProjectPath

my ($destPath) = (@ARGV);

if (!$destPath)
{
	die "usage: perl $0 ProjectPath\n";
}

# load configuration
my $configHash = LoadFile($destPath . "/config.yml");

my $gameDesignExcelsPath = $destPath . "/" . $configHash->{"projectName"} . "_GameDesign/excels";
my $protobufExcelPath = "$destPath/" . $configHash->{"projectName"} . "_ProtobufExcel";

if (!-e $protobufExcelPath){
	mkdir($protobufExcelPath);
}

find({ wanted => \&process, no_chdir => 0}, $gameDesignExcelsPath);

sub process{
	my $filePath = $File::Find::name;
	my $fileName = $_;
	
	if (-d $fileName){
		return;
	}
	
	my $basename = $fileName;
	$basename =~ s/.xlsx//;
	
	my $ss = Spreadsheet::BasicRead->new($filePath);
	
	LogUtil::LogDebug($filePath);
	
	#生成.proto文件
	my $protoStr = "syntax = \"proto2\";\n";
	
	my $numSheets = $ss->numSheets();
	for (my $sheetIndex = 0; $sheetIndex < $numSheets; $sheetIndex++)
	{
		$ss->setCurrentSheetNum($sheetIndex);
		
		my $curSheetName = $ss->currentSheetName();
		if ($curSheetName =~ /^#/){
			next;
		}
		
		LogUtil::LogDebug("Sheet " . $curSheetName);
		
		my $tableComment = "";
		my @configDefine = ();
		
		my $lineNum = 0;
		while ((my $data = $ss->getNextRow()))
		{
			$lineNum++;
			
			if (1 == $lineNum)
			{
				$tableComment = $data->[0];
				$tableComment =~ s/\r?\n/ /smg;
			}
		
			if (($lineNum >= 2) && ($lineNum <= 4))
			{
				push(@configDefine, $data);
			}
		}
		
		$protoStr .= "\n// " . $tableComment . "\n";
		$protoStr .= "message " . ucfirst($basename) .  ucfirst($curSheetName) . "Config" . "\n{\n";
		my $colsNum = scalar(@{$configDefine[0]});
		for (my $i = 0; $i < $colsNum; $i++)
		{
			if ($configDefine[0]->[$i] =~ /^#/)
			{
				next;
			}
			
			my ($colType, $hasLang);
			my $colTypeStr = $configDefine[1]->[$i];
			my @colTypes = split(/\s*;\s*/, $colTypeStr);
			foreach my $tt (@colTypes)
			{
				if ($tt =~ /^lang.*/)
				{
					$hasLang = 1;
					next;
				}
				
				$colType = $tt;
				
				if ($tt =~ /^int$/i)
				{
					$colType = "int32";
				}
				elsif ($tt =~ /^long$/i)
				{
					$colType = "int64";
				}
			}
			
			my $colComment = $configDefine[2]->[$i];
			$colComment =~ s/\r?\n/ /smg;
			
			$protoStr .= "\toptional " . $colType . " " . $configDefine[0]->[$i] . " = " . ($i + 1) . "; // " . $colComment . "\n";
		}
		$protoStr .= "}\n";
	}
	
	if (open(PROTO, ">:raw :utf8", $protobufExcelPath . "/" . ucfirst($basename) . ".proto"))
	{
		print PROTO $protoStr . "\n";
		close(PROTO);
	}
}
