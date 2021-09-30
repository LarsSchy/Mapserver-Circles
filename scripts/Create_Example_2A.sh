#!/bin/bash
#
#	Create examaple 2A for circles in Mapserver
# 
#	Lars Schylberg, 2020-05-23
#

TEST_NUM=Example-2A

CSV_FILE=../data/points_3857.csv
INC_CIRCLE_LAYER=../map/circle_incl.map
MAP_FILE=../map/Circle_${TEST_NUM}.map
EPSG_FILE=../map/epsg
MAPSERV_URL='http://localhost/cgi-bin/mapserv'
PROJECT_DIR=/home/lars/GITHUB/Mapserver_circles

CIRC_WKT_CSV=../data/point_circ_wkt.csv
CIRC_WKT_VRT=../data/point_circ_wkt.vrt
CIRC_WKT_SHP=../data/point_circ_wkt.shp

CIRC_STR_CSV=../data/point_circ_str.csv

IMAGE=../images/Circle_example-2A.png

if [ -f ${INC_CIRCLE_LAYER} ]; then
	rm ${INC_CIRCLE_LAYER} 
fi

if [ -f ${MAP_FILE} ]; then
	rm ${MAP_FILE} 
fi

# create a circles with CIRCULARSTRING
# create the first line in the csv file
echo "ID,WKT" > ${CIRC_STR_CSV}

# populate the rest of the lines with circularstrings
sed 1d $CSV_FILE | \
grep "\\S" --color=none | \
cut -d "," -f 2,3,4 | \
while IFS=, read -r east north radius
do 
    north_min=$(echo "${north}-${radius}" | bc)
    north_max=$(echo "${north}+${radius}" | bc)
	ID=1

cat << EOF >> ${CIRC_STR_CSV}
${ID},"CIRCULARSTRING(${east} ${north_min}, ${east}  ${north_max}, ${east}  ${north_min})"
EOF

	ID=$((ID+1))
done

# function to determine suitable extent

function extent_with_padding () {
    if [ -z "$1" ] && [ -z "$2" ]; then 
        echo "Missing arguments. Syntax:"
        echo "extent_with_padding <csv_file> <padding>"
        return
    fi

	CSV_FILE=$1
	PAD=$2
	
	# sed to delete first line with header
	# grep to remove possible blank lines
	# awk to filter out bounding box values
	# $2 is easting, $3 is northing, $4 is radius in input file

	e_min=$(sed 1d "$CSV_FILE" | grep "\\S" --color=none | \
	awk 'BEGIN {min=20026376} $2 < min {min=$2;rad=$4} 
		END { print min-rad }' FS=",")

	e_max=$(sed 1d "$CSV_FILE" | grep "\\S" --color=none | \
	awk 'BEGIN {max=-20026376} $2 > max {max=$2;rad=$4} 
		END {print max+rad}' FS=",")

	n_min=$(sed 1d "$CSV_FILE" | grep "\\S" --color=none |  \
	awk 'BEGIN {min=20026376} $3 < min {min=$3;rad=$4} 
		END {print min-rad}' FS=",")

	n_max=$(sed 1d "$CSV_FILE" |  grep "\\S" --color=none | \
	awk 'BEGIN {max=-20026376} $3 > max {max=$3;rad=$4} 
		END {print max+rad}' FS=",")

	east_min=$(echo "$e_min - $PAD" | bc )
	east_max=$(echo "$e_max + $PAD" | bc )
	north_min=$(echo "$n_min - $PAD" | bc )
	north_max=$(echo "$n_max + $PAD" | bc )

	echo "$east_min $north_min $east_max $north_max"	
}

# Create mapfile

PADD=10000
EXTENT=$(extent_with_padding "$CSV_FILE" "$PADD")

cat << EOF >> "$MAP_FILE"
MAP 
    NAME "circle_2A"
    STATUS ON
    MAXSIZE 10000
    SIZE 800 600  
	# IMAGECOLOR "#99CCFF"
	
    EXTENT $EXTENT
    UNITS METERS
	SHAPEPATH "../data" 
    # CONFIG "MS_ERRORFILE" "/tmp/debug_circle_2A.txt" 
    CONFIG "PROJ_LIB" "."
    DEBUG 5
	CONFIG "ON_MISSING_DATA" "LOG"
	# CONFIG "MS_OPENLAYERS_JS_URL" "LocalOpenLayers/OpenLayers-ms60.js"

    PROJECTION
        "init=epsg:3857"
    END
    
    WEB
        IMAGEPATH "/tmp/ms_tmp/"
        IMAGEURL "/ms_tmp/"
        METADATA
			"wms_title" "Circle_2A"
            "wms_srs"  "EPSG:3857 EPSG:900913 EPSG:3006 EPSG:4326 EPSG:32633"
            "wms_enable_request"  "*"
        END
    END
	
	# Draw CIRCULARSTRING features from the csv file
	
	LAYER
        NAME "curves_CS"
        TYPE LINE
        GROUP "default"
        CONNECTIONTYPE OGR
        CONNECTION "point_circ_str.csv"
        STATUS ON
        
        CLASS
			# EXPRESSION ([ID] = 1)
			STYLE
				LINECAP BUTT
				WIDTH 2.5
				COLOR 255 0 0
				OFFSET 5 -99
				PATTERN 15 6 END
			END
		END
    END

END
EOF


# create epsg file locally

cat <<EOFILE > $EPSG_FILE
#wgs84
<4326> +proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs  +over <>
#google spherical mercator
<3857> +proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +wktext  +no_defs <>
<900913> +proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs +over <>
# WGS 84 / UTM zone 33N
<32633> +proj=utm +zone=33 +datum=WGS84 +units=m +no_defs  <>
# SWEREF99 TM    
<3006> +proj=utm +zone=33 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs  <>
# ETRS89
<4258> +proj=longlat +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +no_defs  <>
EOFILE

# create mapserver url to run in browser

BBOX=$(echo "$EXTENT" | awk '{printf "%d,%d,%d,%d", $1, $2, $3, $4}')

#cat << EOF2 > ../map/url_circle2.txt
#${MAPSERV_URL}?map=${PROJECT_DIR}/map/$MAP_FILE
#&LAYERS=default
#&VERSION=1.1.1
#&SERVICE=WMS
#&REQUEST=GetMap
#&FORMAT=application/openlayers
#&WIDTH=1800
#&HEIGHT=1000
#&SRS=EPSG:3857
#&BBOX=$BBOX
#EOF2

shp2img -m ../map/Circle_${TEST_NUM}.map -o "${IMAGE}"
