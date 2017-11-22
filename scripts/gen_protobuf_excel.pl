#!/usr/bin/perl

# convert excel to .proto files

use Data::Dumper;
use YAML qw(LoadFile);
use File::Find;
use Spreadsheet::BasicRead;
use File::Path::Tiny;

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

my @allConfigs = ();

find({ wanted => \&process, no_chdir => 0}, $gameDesignExcelsPath);

# 生成 AutoGen/ConfigLoaderAutoGen.cs
&writeConfigLoaderAutoGen();

sub process{
	my $filePath = $File::Find::name;
	my $fileName = $_;
	
	if (-d $fileName){
		return;
	}
	
	my $basename = $fileName;
	$basename =~ s/.xlsx//;
	
	if ($basename =~ /^~/)
	{
		return;
	}
	
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
		
		my $finalClassName = ucfirst($basename) .  ucfirst($curSheetName);
		push(@allConfigs, $finalClassName);
		
		$protoStr .= "\n// " . $tableComment . "\n";
		$protoStr .= "message " . $finalClassName . "Config" . "\n{\n";
		my $colsNum = scalar(@{$configDefine[0]});
		for (my $i = 0; $i < $colsNum; $i++)
		{
			if ($configDefine[0]->[$i] =~ /^#/)
			{
				next;
			}
			
			my $modifier = "optional";
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
				
				if ($tt =~ /\[\s*\]$/)
				{
					$modifier = "repeated";
					
					$tt =~ s/\[\s*\]$//g;
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
			
			$protoStr .= "\t" . $modifier . " " . $colType . " " . $configDefine[0]->[$i] . " = " . ($i + 1) . "; // " . $colComment . "\n";
		}
		$protoStr .= "}\n";
		
		# 生成 AutoGen/ConfigPool/下面的文件
		
		# 生成 StreamAssets/Configs下的json文件
	}
	
	if (open(PROTO, ">:raw :utf8", $protobufExcelPath . "/" . ucfirst($basename) . ".proto"))
	{
		print PROTO $protoStr . "\n";
		close(PROTO);
	}
}

# 生成 AutoGen/ConfigLoaderAutoGen.cs
sub writeConfigLoaderAutoGen{
	my $autoGenIn = $Bin . "/../templates/ConfigLoaderAutoGen.cs.tmpl";
	my $loaderAutoGenOutDir = $destPath . "/" . $configHash->{"projectName"} . "_Client/Assets/Scripts/AutoGen";
	
	File::Path::Tiny::mk($loaderAutoGenOutDir);
	
	if (open(LOADER_AUTO_GEN_IN, $autoGenIn))
	{
		my $autoGenOut = $loaderAutoGenOutDir . "/ConfigLoaderAutoGen.cs";
		if (open(LOADER_AUTO_GEN_OUT, ">$autoGenOut"))
		{
		
			my $outStr = "";
			foreach my $c (@allConfigs)
			{
				$outStr .= "\n			yield return " . $c . "ConfigPool.LoadData(\"file://\" + Application.streamingAssetsPath + \"/Configs/" . $c . ".json\");";
			}
			
			while (my $line = <LOADER_AUTO_GEN_IN>)
			{
				if ($line =~ m!//CONFIG_POOL_STATEMENT//!)
				{
					print LOADER_AUTO_GEN_OUT $outStr . "\n";
				}
				else
				{
					print LOADER_AUTO_GEN_OUT $line;
				}
			}
			
			close(LOADER_AUTO_GEN_OUT);
		}
		
		close(LOADER_AUTO_GEN_IN);
	}
	
	my $protobufClassesPath = $destPath . "/" . $configHash->{"projectName"} . "_Client/Assets/Scripts/ProtobufClasses";
	

}
