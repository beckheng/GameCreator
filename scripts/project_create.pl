#!/usr/bin/perl

use Data::Dumper;
use YAML qw(LoadFile);
use File::Path::Tiny;
use File::Copy;

use strict;

$|++;

use FindBin qw($Bin);

use lib "$Bin/perlib";

use LogUtil;

# usage : perl project_create.pl ProjectPath ProjectName

# load configuration
my $configHash = LoadFile($Bin . "/config.yml");

my ($destPath, $projName) = (@ARGV);

if (!$destPath)
{
	&usage();
}

if (!$projName)
{
	&usage();
}

$projName = ucfirst($projName);
my $savePath = $destPath . "/" . $projName;
my $gameClientPath = $savePath . "/" . $projName . "_Client";
my $gameArtsPath = $savePath . "/" . $projName . "_Arts";

my $gameDesignPath = $savePath . "/" . $projName . "_GameDesign";
my $gameDesignDocsPath = $savePath . "/" . $projName . "_GameDesign/docs";
my $gameDesignExcelsPath = $savePath . "/" . $projName . "_GameDesign/excels";

my $protobufDefinePath = $savePath . "/" . $projName . "_ProtobufDefine";

LogUtil::LogDebug("Will Create Project on \"" . $savePath . "\"");

# create sub directories
foreach my $p ($savePath, $gameClientPath, $gameDesignPath, $gameArtsPath, $gameDesignDocsPath, $gameDesignExcelsPath, $protobufDefinePath)
{
	if (!-e($p))
	{
		my $cmd = "mkdir " . $p;
		LogUtil::LogDebug($cmd);
		File::Path::Tiny::mk($p);
	}
}

# clone KCore
my $kcorePath = "KCore";
if (-e($kcorePath))
{
	File::Path::Tiny::rm($kcorePath);
}
my $cloneKCoreCMD = "git clone " . $configHash->{"kcore"};
LogUtil::LogDebug($cloneKCoreCMD);
system($cloneKCoreCMD);

if (!chdir($kcorePath))
{
	die $!;
}

my $archiveCmd = "git archive -o ../kk.zip HEAD";
LogUtil::LogDebug($archiveCmd);
system($archiveCmd);

if (!chdir(".."))
{
	die $!;
}

# create Unity sub directories
foreach my $p ($gameClientPath, $gameArtsPath)
{
	if (!-e($p))
	{
		my $cmd = "mkdir " . $p;
		LogUtil::LogDebug($cmd);
		File::Path::Tiny::mk($p);
	}
	
	foreach my $subPath (
		"Assets/Scripts",
		"Assets/Scenes",
		"Assets/StreamingAssets",
		"Assets/Resources",
		"Assets/Arts/UI",
		"Assets/Arts/Models",
		"Assets/Arts/Scenes",
		"Assets/Arts/Effects",
	)
	{
		my $cmd = "mkdir " . $p . "/" . $subPath;
		LogUtil::LogDebug($cmd);
		File::Path::Tiny::mk($p . "/" . $subPath);
	}
	
	# link the KCore
	if (-e("kk.zip"))
	{
		my $unzipKCoreCMD = "unzip -o -q kk.zip -d " . $p . "/Assets/Scripts/KCore";
		LogUtil::LogDebug($unzipKCoreCMD);
		system($unzipKCoreCMD);
	}
	
	copy($Bin . "/../templates/smcs.rsp", $p . "/Assets/");
}

LogUtil::LogDebug("delete kk.zip");
unlink("kk.zip");

LogUtil::LogDebug("delete " . $kcorePath);
File::Path::Tiny::rm($kcorePath);

# 复制模板文件
copy($Bin . "/../templates/ProtobufTemplate.proto", $protobufDefinePath . "/");
copy($Bin . "/../templates/DesignTemplate.xlsx", $gameDesignExcelsPath . "/");

# 输出config.yml到工程根目录
my $projConfigYamlFile = $savePath . "/config.yml";
if (open("CONF", ">$projConfigYamlFile"))
{
	print CONF "---\n";
	print CONF "projectName: " . $projName . "\n";
	close(CONF);
}

sub usage
{
	die "perl $0 ProjectPath ProjectName\n";
}
