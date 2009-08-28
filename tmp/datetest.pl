use DateTime::Format::ISO8601;
use Class::Date 'now';
use R::Dump;

#$ENV{TZ} = 0;
my $d = now()->to_tz('GMT+5.3');
#$d->tzoffset(300);
print $d->tzoffset,"\n";
print $d->tzdst,"\n";
print $d->strftime('%Y%m%dT%H%M%S').sprintf( '%+03d%02d', $d->tzoffset / 3600, ( $d->tzoffset % 3600 ) / 60  ),"\n";
print Dump $d;
__END__

for (qw(20090816T010203.004+0330 20090816T010203)) {
	my $dt = DateTime::Format::ISO8601->parse_datetime($_);
	#$dt->set_formatter(DateTime::Format::ISO8601->new() );
	print $dt->strftime('%Y%m%dT%H%M%S.%3N%z'),"\n";
	#print Dump $dt;
}