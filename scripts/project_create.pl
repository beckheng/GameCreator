#!/usr/bin/perl

use Data::Dumper;
use YAML qw(LoadFile);

use strict;

$|++;

use FindBin qw($Bin);

#use lib ".";

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

print "Will Create Project on \"" . $savePath . "\"\n";

# create sub directories
foreach my $p ($savePath, $gameClientPath, $gameDesignPath, $gameArtsPath, $gameDesignDocsPath, $gameDesignExcelsPath, $protobufDefinePath)
{
	if (!-e($p))
	{
		my $cmd = "mkdir -p " . $p;
		print $cmd . "\n";
		system($cmd);
	}
}

# clone KCore
my $kcorePath = "KCore";
if (-e($kcorePath))
{
	system("rm -rf " . $kcorePath);
}
my $cloneKCoreCMD = "git clone " . $configHash->{"kcore"};
print $cloneKCoreCMD . "\n";
system($cloneKCoreCMD);

if (!chdir($kcorePath))
{
	die $!;
}

my $archiveCmd = "git archive -o ../kk.zip HEAD";
print $archiveCmd . "\n";
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
		my $cmd = "mkdir -p " . $p;
		print $cmd . "\n";
		system($cmd);
	}
	
	foreach my $subPath (
		"Assets/Scripts",
		"Assets/Scenes",
		"Assets/StreamingAssets",
		"Assets/Resources",
	)
	{
		my $cmd = "mkdir -p " . $p . "/" . $subPath;
		print $cmd . "\n";
		system($cmd);
	}
	
	# link the KCore
	if (-e("kk.zip"))
	{
		my $unzipKCoreCMD = "unzip -o -q kk.zip -d " . $p . "/Assets/Scripts/KCore";
		print $unzipKCoreCMD . "\n";
		system($unzipKCoreCMD);
	}
}

system("rm -f kk.zip");
system("rm -rf " . $kcorePath);

# 复制模板文件
system("cp " . $Bin . "/../templates/ProtobufTemplate.proto " . $protobufDefinePath . "/");
system("cp " . $Bin . "/../templates/DesignTemplate.xlsx " . $gameDesignExcelsPath . "/");

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
