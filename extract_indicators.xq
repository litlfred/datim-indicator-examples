
declare namespace csd = "urn:ihe:iti:csd:2013"; 
declare namespace s = "urn:schemas-microsoft-com:office:spreadsheet";
declare namespace o = "urn:schemas-microsoft-com:office:office";
declare namespace x = "urn:schemas-microsoft-com:office:excel";
declare namespace d = "http://www.datim.org";
declare namespace svs = "urn:ihe:iti:svs:2008";

import module namespace uuid = "https://github.com/openhie/openinfoman-datim/uuid" at "uuid.xqm";
import module namespace functx = "http://www.functx.com";

let $doc := doc("IndicatorList_June23.xml")
let $results_table := $doc/s:Workbook/s:Worksheet[1]/s:Table 

let $results_header := $results_table/s:Row[1] 
let $results_rows := $results_table/s:Row[position() > 1] 

let $pepfar_codes := distinct-values($results_rows/s:Cell[1]/s:Data/text())
let $datim_codes := $results_rows/s:Cell[4]/s:Data
let $unique_datim_codes := distinct-values($datim_codes/text())

let $time := current-dateTime()


let $datim_uuid_namespace := "63051732-c77c-466e-9ce1-03c1755b1765"  
let $disag_oid := "1.2.3.4.5.7.8.9" (: Obviously fake:)

let $csd_doc := 
  <csd:CSD xmlns:d='http://www.datim.org'>
    <csd:organizationDirectory/>
    <csd:serviceDirectory>
      {
	for $code in $unique_datim_codes
	let $matching_rows := $datim_codes[text() = $code]/../..
	let $pepfar_code := $matching_rows[1]/s:Cell[1]/s:Data/text() 
	let $desc := $matching_rows[1]/s:Cell[3]/s:Data/text() 
	let $type := $matching_rows[1]/s:Cell[5]/s:Data/text() 
	let $svc_type := $matching_rows[1]/s:Cell[6]/s:Data/text() 
	let $disag_type := $matching_rows[1]/s:Cell[7]/s:Data/text() 
	let $disag_val := $matching_rows[1]/s:Cell[8]/s:Data/text() 
	let $rcode := replace($code,'/','_')
	let $uuid := uuid:generate($rcode,$datim_uuid_namespace)
	let $pf_cps := for $cp in string-to-codepoints($pepfar_code) return string($cp)
	return 
	  <csd:service entityID="urn:uuid:{$uuid}">
	    <csd:codedType assigningAuthorityName="urn:www.datim.org:data-element" code="{$rcode}">{$desc}</csd:codedType>
	    <csd:codedType assigningAuthorityName="urn:www.datim.org:pepfar-code" code="{$pepfar_code}"/>
	    <csd:codedType assigningAuthorityName="urn:www.datim.org:type" code="{$type}"/>
	    <csd:codedType assigningAuthorityName="urn:www.datim.org:service-type" code="{$svc_type}"/>
	    {
	      if (  not($disag_type = 'N/A') and not($disag_val = '(default)'))
	      then
		  <csd:extension urn="urn:www.datim.org" type="disaggregation">
		    {
		      for $d in tokenize($disag_type,'_')
		      let $cps := for $cp in string-to-codepoints($d) return string($cp)
		      let $c_oid := concat($disag_oid , '.' , string-join($pf_cps) , '.' , string-join($cps))
		      return <d:disaggregatorSet concept="{$d}" id="{$c_oid}"/>
		    }
		  </csd:extension>
	      else ()
            }
            <csd:record 
	      created="{$time}"
	      updated="{$time}" 
	      status="Active"
	      sourceDirectory="http://www.datim.org"/>
	  </csd:service>
      }
    </csd:serviceDirectory>
    <csd:organizationDirectory/>
    <csd:facilityDirectory/>
    <csd:providerDirectory/>
  </csd:CSD>



let $disag_codes := distinct-values(for $t in $results_rows/s:Cell[7]/s:Data/text() return tokenize($t,'_'))
let $date := replace(substring-before(string($time),'T'),'-','')

let $disag_rows := $results_rows[
  not(  s:Cell[7]/s:Data/text()  = 'N/A')
  and not (  s:Cell[7]/s:Data/text()  = '(default)')
  ]

let $disag_docs := map:merge(
  for $code in $pepfar_codes
  let $codes := distinct-values($disag_rows[s:Cell[1]/s:Data/text() = $code]/s:Cell[4]/s:Data/text())
  let $matching_rows := $results_rows[s:Cell[4]/s:Data/text() = $codes]
  let $disag_vals :=  
	    for $m in $matching_rows
	    let $disag_types := tokenize($m/s:Cell[7]/s:Data/text(),'_')
	    for $type at $p in $disag_types
              let $disaggregators:= replace(replace(functx:trim($m/s:Cell[8]/s:Data/text()),"^\(",''),"\)$",'')
              let $disaggregator_set := 
                for $v in functx:get-matches($disaggregators,"[^,]+")
		return normalize-space($v)
            let $val := $disaggregator_set[$p]
            return <val type="{$type}">{$val}</val>
  
  return 
    for $type in distinct-values($disag_vals/@type)
      let $cps := for $cp in string-to-codepoints($type) return string($cp)
      let $pf_cps := for $cp in string-to-codepoints($code) return string($cp)
      let $c_oid := concat($disag_oid , '.' , string-join($pf_cps) , '.' , string-join($cps))
      return	map{ 
        concat($type,'-',$code) :
          <svs:ValueSet  xmlns:svs="urn:ihe:iti:svs:2008" id="{$c_oid}" version="{$date}" displayName="DATIM disaggregator for {$type} on {$code}">
	    <svs:ConceptList xml:lang="en-US" >
	    {
	     for $t in distinct-values($disag_vals[@type = $type]/text())
	     return <svs:Concept code="{$t}" displayName="{$t}" codeSystem="urn:www.datim.org:disaggregators:{$code}:{$type}"/>
	    }
	  </svs:ConceptList>
         </svs:ValueSet>
        }

  
  )

  return 
    (
      file:write('csd_indicators.xml',$csd_doc)
      , 
      for $k in map:keys($disag_docs)
      return file:write(concat('./disaggregators/' , $k,'.xml'),map:get($disag_docs,$k))

  )
