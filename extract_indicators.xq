
declare namespace csd = "urn:ihe:iti:csd:2013"; 
declare namespace s = "urn:schemas-microsoft-com:office:spreadsheet";
declare namespace o = "urn:schemas-microsoft-com:office:office";
declare namespace x = "urn:schemas-microsoft-com:office:excel";
declare namespace d = "http://www.datim.org";
declare namespace svs = "urn:ihe:iti:svs:2008";

import module namespace uuid = "https://github.com/openhie/openinfoman-datim/uuid" at "uuid.xqm";
import module namespace functx = "http://www.functx.com";

let $targets_table := doc("DATIM MER Indicators List.xml")/s:Workbook/s:Worksheet[1]/s:Table 
let $results_table := doc("DATIM MER Indicators List.xml")/s:Workbook/s:Worksheet[2]/s:Table 

let $results_header := $results_table/s:Row[1] 
let $results_rows := $results_table/s:Row[position() > 1] 

let $data_elements := $results_rows/s:Cell[2]/s:Data
let $unique_data_elements := distinct-values($data_elements/text())

let $datim_uuid_namespace := "63051732-c77c-466e-9ce1-03c1755b1765"  
let $disag_oid := "1.2.3.4.5.7.8.9" (: Obviously fake:)

let $csd_doc := 
  <csd:CSD xmlns:d='http://www.datim.org'>
    <csd:organizationDirectory/>
    <csd:serviceDirectory>
      {
	for $code in $unique_data_elements 	
	let $matching_rows := $data_elements[text() = $code]/../..
	let $desc := $matching_rows[1]/s:Cell[1]/s:Data/text()
	let $uuid := uuid:generate($code,$datim_uuid_namespace)
	return 
	  <csd:service entityID="urn:uuid:{$uuid}">
	    <csd:codedType assigningAuthorityName="urn:www.datim.org:dataelement" code="{$code}">{$desc}</csd:codedType>
	    {
              let $disag_sets := 
	        for $row in $matching_rows
	        let $disaggregators:= replace(replace($row/s:Cell[3]/s:Data/text(),"^\S*\(",''),"\)\S*",'')
		let $disaggregator_set := 
	 	  for $m in functx:get-matches($disaggregators,"[^,]+")
		  where not( functx:all-whitespace($m)) and not ($m = 'default')
		  return normalize-space($m)
		return
		  if (count($disaggregator_set) > 0)
		  then 		 
		    <d:disaggregatorSet>
		      {
			for $d in $disaggregator_set 
			return   <d:disaggreator>{$d}</d:disaggreator>
		      }
	            </d:disaggregatorSet>
		  else ()
	      return
               if (count($disag_sets) > 0) 
		then 	  
		  <csd:extension urn="urn:www.datim.org" type="Disaggregators">
		    {$disag_sets}
		  </csd:extension>
		else ()
            }
            <csd:record 
	      created="2014-12-01T14:00:00+00:00"
	      updated="2014-12-01T14:00:00+00:00" 
	      status="Active"
	      sourceDirectory="http://www.datim.org"/>
	  </csd:service>
      }
    </csd:serviceDirectory>
    <csd:organizationDirectory/>
    <csd:facilityDirectory/>
    <csd:providerDirectory/>
  </csd:CSD>




let $unique_disaggergators := 
  distinct-values(
    for $row in $results_rows
    let $disaggregators:= replace(replace($row/s:Cell[3]/s:Data/text(),"^\S*\(",''),"\)\S*",'')
    return 
      for $m in functx:get-matches($disaggregators,"[^,]+")
      where not( functx:all-whitespace($m)) and not ($m = 'default')
      return normalize-space($m)
  )

let $disag_doc :=	
  <svs:ValueSet  xmlns:svs="urn:ihe:iti:svs:2008" id="{$disag_oid}" version="20150618" displayName="DATIM Disaggregators">
    <svs:ConceptList xml:lang="en-US">
      {
	for $disaggergator in $unique_disaggergators 
	return <svs:Concept code="{$disaggergator}" displayName="{$disaggergator}" codeSystem="urn:www.datim.org:disaggregators"/>
      }
    </svs:ConceptList>
  </svs:ValueSet>

return 
  (
    file:write('csd_indicators.xml',$csd_doc)
    ,file:write('disaggreators.xml',$disag_doc)
  )
