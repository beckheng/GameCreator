#!/usr/bin/perl

# convert excel to .proto files

use Data::Dumper;
use YAML qw(LoadFile);
use File::Find;
use Spreadsheet::BasicRead;
use File::Path::Tiny;
use JSON::XS;

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

my $json = JSON::XS->new->pretty(0)->allow_nonref;
$json->canonical(1);

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
		my @fieldCommentDefine = (); # 字段注释声明
		my @fieldTypeDefine = (); # 字段类型声明
		my @fieldNameDefine = (); # 字段名称声明
		my @colDatas = (); # 行数据
		
		my $lineNum = 0;
		while ((my $data = $ss->getNextRow()))
		{
			$lineNum++;
			
			if (1 == $lineNum)
			{
				$tableComment = $data->[0];
				$tableComment =~ s/\r?\n/ /smg;
				next;
			}
			
			if (2 == $lineNum)
			{
				@fieldCommentDefine = @{$data};
				next;
			}
			
			if (3 == $lineNum)
			{
				@fieldTypeDefine = @{$data};
				next;
			}
		
			if (4 == $lineNum)
			{
				@fieldNameDefine = @{$data};
				next;
			}
			
			if ($lineNum >= 5)
			{
				push(@colDatas, $data);
			}
		}
		
		my $finalClassName = ucfirst($basename) .  ucfirst($curSheetName);
		push(@allConfigs, $finalClassName);
		
		my @colDefines = (); # 列定义
		
		$protoStr .= "\n// " . $tableComment . "\n";
		$protoStr .= "message " . $finalClassName . "Config" . "\n{\n";
		my $colsNum = scalar(@fieldNameDefine);
		for (my $i = 1; $i < $colsNum; $i++)
		{
			if ($fieldNameDefine[$i] =~ /^#/)
			{
				next;
			}
			
			my $modifier = "optional";
			my ($colType, $hasLang, $isArray);
			my $colTypeStr = $fieldTypeDefine[$i];
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
					$isArray = 1;
					
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
			
			my $colComment = $fieldCommentDefine[$i];
			$colComment =~ s/\r?\n/ /smg;
			
			$protoStr .= "\t" . $modifier . " " . $colType . " " . $fieldNameDefine[$i] . " = " . ($i) . "; // " . $colComment . "\n";
			
			push(@colDefines, {"name" => $fieldNameDefine[$i], "type" => $colType, "isArray" => $isArray, "index" => $i});
		}
		$protoStr .= "}\n";
		
		# 生成 AutoGen/ConfigPool/下面的文件
		&writeConfigPoolAutoGen($finalClassName, @colDefines);
		
		# 生成 StreamAssets/Configs下的json文件
		&genJSONFile($finalClassName, [@colDefines], [@colDatas]);
	}
	
	if (open(PROTO, ">:raw :utf8", $protobufExcelPath . "/" . ucfirst($basename) . ".proto"))
	{
		print PROTO $protoStr . "\n";
		close(PROTO);
	}
}

# 生成 StreamAssets/Configs下的json文件
sub genJSONFile {
	my $className = shift @_;
	my @colDefines = @{shift @_};
	my @colDatas = @{shift @_};
	
	my $jsonOutDir = $destPath . "/" . $configHash->{"projectName"} . "_Client/Assets/StreamingAssets/Configs";
	
	File::Path::Tiny::mk($jsonOutDir);
	
	my $jsonOut = $jsonOutDir . "/" .$className . ".json";
	
	if (open(JSON_AUTO_GEN_OUT, ">:utf8", $jsonOut))
	{
		foreach my $rd (@colDatas)
		{
			my $hash = {};
			
			foreach my $c (@colDefines)
			{
				if ($c->{"isArray"})
				{
					my @tmpArr = split(";", $rd->[$c->{"index"}]);
					$hash->{$c->{"name"}} = [@tmpArr];
				}
				else
				{
					$hash->{$c->{"name"}} = $rd->[$c->{"index"}];
				}
			}
			
			print JSON_AUTO_GEN_OUT $json->encode($hash) . "\n";
		}
		
		close(JSON_AUTO_GEN_OUT);
	}
}

# 生成 AutoGen/ConfigPool/下面的文件
sub writeConfigPoolAutoGen {
	my $className = shift @_;
	my @colDefines = @_;
	
	my $autoGenIn = $Bin . "/../templates/ConfigPool.cs.tmpl";
	my $configPoolAutoGenOutDir = $destPath . "/" . $configHash->{"projectName"} . "_Client/Assets/Scripts/AutoGen/ConfigPool";
	
	File::Path::Tiny::mk($configPoolAutoGenOutDir);
	
	if (open(CONFIG_POOL_AUTO_GEN_IN, $autoGenIn))
	{
		my $autoGenOut = $configPoolAutoGenOutDir . "/" . $className . "ConfigPool.cs";
		if (open(CONFIG_POOL_AUTO_GEN_OUT, ">$autoGenOut"))
		{
		
			my $keyType = "string";
			if ($colDefines[0]->{"type"} eq "int32")
			{
				$keyType = "int";
			}
			elsif ($colDefines[0]->{"type"} eq "int64")
			{
				$keyType = "long";
			}
			elsif ($colDefines[0]->{"type"} eq "float")
			{
				$keyType = "float";
			}
			
			my $assignStr = "";
			foreach my $c (@colDefines)
			{
				my $getValStatement = "Value";
				if ($c->{"type"} eq "int32")
				{
					$getValStatement = "AsInt";
				}
				elsif ($c->{"type"} eq "int64")
				{
					$getValStatement = "AsInt";
				}
				elsif ($c->{"type"} eq "float")
				{
					$getValStatement = "AsFloat";
				}
				
				if ($c->{"isArray"})
				{
					$assignStr .= "\n					var tmp_" . $c->{"name"} . " = jsonObject[\"" . $c->{"name"} . "\"].AsArray;";
					$assignStr .= "\n					for (int i = 0; i < tmp_" . $c->{"name"} . ".Count; i++)";
					$assignStr .= "\n					{";
					$assignStr .= "\n						config." . $c->{"name"} . ".Add(tmp_" . $c->{"name"} . "[i]." . $getValStatement . ");";
					$assignStr .= "\n					}";
				}
				else
				{
					$assignStr .= "\n					config." . $c->{"name"} . " = jsonObject[\"" . $c->{"name"} . "\"]." . $getValStatement . ";";
				}
			}
			
			while (my $line = <CONFIG_POOL_AUTO_GEN_IN>)
			{
				$line =~ s!//CLASS_NAME//!$className!g;
				$line =~ s!//KEY_NAME//!$colDefines[0]->{"name"}!g;
				$line =~ s!//FIELD_ASSIGN_STATEMENT//!$assignStr!g;
				$line =~ s!//KEY_TYPE//!$keyType!g;
				
				print CONFIG_POOL_AUTO_GEN_OUT $line;
			}
			
			close(CONFIG_POOL_AUTO_GEN_OUT);
		}
		
		close(CONFIG_POOL_AUTO_GEN_IN);
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
				if ( ($c eq "MessagesMsg")
					|| ($c eq "MessagesMsgEN") 
					|| ($c eq "MessagesMsgTC") 
					|| ($c eq "MessagesMsgSC") 
				)
				{
					next;
				}
				$outStr .= "\n			yield return " . $c . "ConfigPool.LoadData(\"/Configs/" . $c . ".json\");";
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
}
