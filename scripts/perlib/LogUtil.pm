package LogUtil;

sub LogDebug($)
{
	my $msg = shift @_;
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
	
	$year += 1900;
	$mon += 1;
	
	my $timestatmp = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
	
	print $timestatmp .  " [Debug] " . $msg . "\n";
}

1;
