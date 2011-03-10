package CIF::Message::IODEF;
use base CIF::DBI;

use strict;
use warnings;

__PACKAGE__->table('v_iodef');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid source confidence severity description restriction message created/);
__PACKAGE__->columns(All => qw/id uuid confidence severity description restriction created/);

use XML::IODEF;
use XML::LibXML;
use CIF::Message::Structured;

sub insert {
    my $self = shift;
    my $args = { %{+shift} };
    
    my $parser = XML::LibXML->new();
    my $doc = $parser->parse_string($args->{'message'});
    
    my @incidents = $doc->findnodes('//Incident');
    my @results;
    foreach my $i (@incidents){
        my $iodef = XML::IODEF->new();
        $iodef->in('<IODEF-Document>'.$i->toString().'</IODEF-Document>');

        my $source = $iodef->get('IncidentIncidentIDname');

        my $desc = $i->findvalue('//Incident/Description');
        my $restriction = $i->getAttribute('restriction') || 'private';
        my $detecttime = $i->findvalue('//Incident/DetectTime') || undef;

        my @confidence = $i->findnodes('//Incident/Assessment/Confidence');
        my $conf;
        if($#confidence >= 0){
            $conf = $confidence[0]->textContent();
        }

        my @impacts = $i->findnodes('//Incident/Assessment/Impact');
        my $severity = 'low';
        my $type;
        my $impact;
        if($#impacts >= 0){
            $severity = $impacts[0]->getAttribute('severity');
            $impact   = $impacts[0]->textContent();
        }
        
        my $mid = CIF::Message::Structured->insert({
            format      => 'IODEF',
            type        => $impact,
            source      => $source,
            severity    => $severity,
            description => $desc,
            restriction => $restriction,
            confidence  => $conf,
            detecttime  => $detecttime,
            message     => $iodef->out(),
            impact      => $impact,
        });
        push(@results,$mid);
    }
    return(@results) if($#results > 0);
    return($results[0]);
}

sub fromIODEF {
    my $self = shift;
    my $msg = shift;

    my $iodef = XML::IODEF->new();
    $iodef->in($msg);
    my $hash = $iodef->to_hash();

    my ($prefix,$asn,$rir,$cc);
    if(exists($hash->{'IncidentEventDataFlowSystemAdditionalData'})){
        my @adm = @{$hash->{'IncidentEventDataFlowSystemAdditionalDatameaning'}};
        my @ad = @{$hash->{'IncidentEventDataFlowSystemAdditionalData'}};
        my %m = map { $adm[$_],$ad[$_] } (0 ... $#adm);
        $prefix = $m{'prefix'};
        $asn    = $m{'asn'};
        $rir    = $m{'rir'};
    }

    my $h = {
        address     => $hash->{'IncidentEventDataFlowSystemNodeAddress'}[0],
        description => $hash->{'IncidentDescription'}[0],
        detecttime  => $hash->{'IncidentDetectTime'}[0],
        confidence  => $hash->{'IncidentAssessmentConfidence'}[0],
        impact      => $hash->{'IncidentAssessmentImpact'}[0],
        protocol    => $hash->{'IncidentEventDataFlowSystemServiceip_protocol'}[0],
        portlist    => $hash->{'IncidentEventDataFlowSystemServicePortlist'}[0],
        severity    => $hash->{'IncidentAssessmentImpactseverity'}[0],
        source      => $hash->{'IncidentIncidentIDname'}[0],
        restriction => $hash->{'Incidentrestriction'}[0],
        asn         => $asn,
        cidr        => $prefix,
        cc          => $hash->{'IncidentEventDataFlowSystemNodeLocation'}[0],
        rir         => $rir,
        alternativeid               => $hash->{'IncidentAlternativeIDIncidentID'}[0],
        alternativeid_restriction   => $hash->{'IncidentAlternativeIDIncidentIDrestriction'}[0],
    };
    return($h);
}
    
1;
