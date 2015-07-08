module namespace uuid = "https://github.com/openhie/openinfoman-datim/uuid";
import module namespace functx = "http://www.functx.com";

declare function uuid:tobits($tokens) {
  if (count($tokens) > 1)
  then  ( 
          bin:hex(concat($tokens[1],$tokens[2])),
          uuid:tobits(subsequence($tokens,3))
        )
  else $tokens
};

declare function uuid:generate($name,$namespace) {
  (: adapted from http://www.ietf.org/rfc/rfc4122.txt and https://gist.github.com/dahnielson/508447 :)
  let $bits := uuid:tobits(functx:chars(translate($namespace,'-','' )))
  let $s_bits := serialize($bits,map{'method':'raw'})
  let $hash := serialize(xs:hexBinary(hash:md5(concat($s_bits,  $name))))

  let $uuid :=
    concat(
      substring( $hash,1, 8)
      ,'-'
      ,substring( $hash,9, 4)  
      ,'-'
      ,xs:hexBinary(bin:or(bin:and(bin:hex(substring($hash, 13, 4)),bin:hex('0FFF')),bin:hex('3000')))
      ,'-'
       ,xs:hexBinary(bin:or( bin:and(bin:hex(substring( $hash,17, 4)) , bin:hex('3FFF')) , bin:hex('8000')))
      ,'-'
      ,substring( $hash,21, 12)
      )
  return lower-case($uuid)
};

