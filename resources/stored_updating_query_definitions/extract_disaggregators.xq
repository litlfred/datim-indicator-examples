declare namespace csd = "urn:ihe:iti:csd:2013"; 
declare namespace d = "http://www.datim.org";
declare namespace svs = "urn:ihe:iti:svs:2008";
declare namespace dxf = "http://dhis2.org/schema/dxf/2.0";


import module namespace csd_webconf =  "https://github.com/openhie/openinfoman/csd_webconf";
import module namespace csd_dm = "https://github.com/openhie/openinfoman/csd_dm";
import module namespace svs_lsvs = "https://github.com/openhie/openinfoman/svs_lsvs";
import module namespace uuid = "https://github.com/openhie/openinfoman-datim/uuid";
import module namespace functx = "http://www.functx.com";

declare variable $careServicesRequest as item() external; 


let $dxf := $careServicesRequest/dxf
let $disag_oid := $careServicesRequest/oid/text()


let $categories := $dxf/dxf:metaData/dxf:categories/dxf:category

return
  for $categoryCombo in $dxf/dxf:metaData/dxf:categoryCombos/dxf:categoryCombo
  let $cc_date := xs:dateTime(substring(string($categoryCombo/@lastUpdated),1,19))
  let $cc_id := $categoryCombo/@id
  let $cc_oid := string-join(for $cp in string-to-codepoints(string($cc_id)) return string($cp))
  let $cc_name := string($categoryCombo/@name)

  return
    for $category_ref in $categoryCombo/dxf:categories/dxf:category
    let $cat_ref_date := xs:dateTime(substring(string($category_ref/@lastUpdated),1,19))
    let $cat_id := $category_ref/@id
    let $cat_oid := string-join(for $cp in string-to-codepoints(string($cat_id)) return string($cp))      
    let $category :=  ($categories[@id = $cat_id])[1]
    let $cat_date := xs:dateTime(substring(string($category/@lastUpdated),1,19))
    let $cat_name := string($category/@name)
    let $svs_vals_0 :=
      for $catOption in $category/dxf:categoryOptions/dxf:categoryOption
      let $cat_opt_date := xs:dateTime(substring(string($catOption/@lastUpdated),1,19))
      let $cat_opt_name := string($catOption/@name)
      let $cat_opt_id := string($catOption/@id)
      let $date := max(($cat_ref_date,$cat_date,$cat_opt_date))
      return <svs:Concept code="{$cat_opt_id}" displayName="{$cat_opt_name}" codeSystem="urn:www.datim.org:disaggregators:{$cc_name}:{$cat_name}" lu="{$date}"/>

    let $date := max(($cc_date, for $d in $svs_vals_0/@lu return xs:dateTime($d)))
    let $svs_vals_1 := functx:remove-attributes-deep($svs_vals_0,'lu')

    let $oid :=  concat($disag_oid , '.' , $cc_oid , '.' , $cat_oid)	
    let $svs_doc :=
      <svs:ValueSet  xmlns:svs="urn:ihe:iti:svs:2008" id="{$oid}" version="{$date}" displayName="DATIM disaggregator for {$cc_name} on {$cat_name}">
	<svs:ConceptList xml:lang="en-US" >
	  {$svs_vals_1}
	</svs:ConceptList>
      </svs:ValueSet>

    return svs_lsvs:insert($csd_webconf:db,$svs_doc) 




