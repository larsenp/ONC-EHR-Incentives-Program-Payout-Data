// the plain is to have all custom JS that supports the main site function here
// document.ready calls will stay in layout.haml/page level code, for now

var map, markers; // for leaflet mapping
var features_clicked = [] // for comparison features

function load_geojson_as_cluster(data_url,fit_bounds){
  $("#map").showLoading();
  $.getJSON(data_url, function(data){
    // clear all markers
    if(typeof(markers) != "undefined"){map.removeLayer(markers);}

    markers = new L.MarkerClusterGroup();
    var geoJsonLayer = L.geoJson(data, {
      onEachFeature: function (feature, layer) {
        props = feature.properties
        popup = ""
        if(props["PROVIDER - ORG NAME"]){popup += "<strong>" + props["PROVIDER - ORG NAME"]+"</strong>"}
        if(props["PROVIDER NAME"]){popup += "<strong>" + props["PROVIDER NAME"]+"</strong>"}
        popup += "<br />"+props["PROVIDER  ADDRESS"]
        popup += "<br />"+props["PROVIDER CITY"]+", " + props["PROVIDER STATE"] + " " + props["PROVIDER ZIP 5 CD"]
        popup += "<br /><br /> Phone: " + props["PROVIDER PHONE NUM"]
        popup += "<br /><br /> NPI: " + "<a href='https://npiregistry.cms.hhs.gov/NPPESRegistry/DisplayProviderDetails.do?searchNpi=1114922341&city=&firstName=&orgName=&searchType=org&state=&npi="+props["PROVIDER NPI"]+"&orgDba=&lastName=&zip=' target=_blank>"+props["PROVIDER NPI"]+"</a>"
        if(props["PROVIDER CCN"]){ popup += " | CCN: <a href='http://www.qualitycheck.org/consumer/searchresults.aspx?nm="+props["PROVIDER CCN"]+"' target=_blank>" + props["PROVIDER CCN"] + "</a>"}
        layer.bindPopup(popup)
        layer.on('click', onFeatureClick);
      }
    });
    markers.addLayer(geoJsonLayer);
    map.addLayer(markers);
    if(fit_bounds == true){map.fitBounds(markers.getBounds());}
    $("#map").hideLoading();
  })
}

function onFeatureClick(e){
  features_clicked.push(e.target.feature)
  constructComparisonTable()
}

function constructComparisonTable(){
  $("#comparison_tables").html("") // clear the comparison table div
  $.each(features_clicked, function(n,feature){
    $.getJson("#{PUBLIC_HOST}/db/onc/ProvidersPaidByEHRProgram_Dec2012_HOSP_FINAL/"+feature["PROVIDER CCN"]+".json", function(data){
      $("#comparison_tables").append("<table id='table"+n+"' width='100%'></table>")
      $("#table"+n).html("<thead></thead><tbody></tbody>")
      hcahps_props = data.hcahps
      column_title = hcahps_props.hospital_name
      $("#table"+n+" thead").append("<tr><th><strong>Measure<strong></th><th><strong>"+column_title+"<strong><br />Last updated at "+hcahps_props._updated_at+"</th></tr>");
      $.each( hcahps_props, function(k, v){
        key = k.split("_").join(" ")
        if(k.split("_")[0] == "percent"){v = "<div class=progress><span class=meter style='width: "+v+"%'>&nbsp;"+v+"</span></div>"}
        $("#table"+n+" tbody").append("<tr><td>"+key+"</td><td>"+v+"</td><td></td></tr>")
      });
    });
  })
}

