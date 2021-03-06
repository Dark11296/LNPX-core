#! /bin/bash
if [[ -z "${UUID}" ]]; then
  UUID="4890bd47-5180-4b1c-9a5d-3ef686543112"
fi

if [[ -z "${AlterID}" ]]; then
  AlterID="10"
fi

if [[ -z "${V2_Path}" ]]; then
  V2_Path="/FreeApp"
fi

if [[ -z "${S_Path}" ]]; then
  S_Path="/black-box"
fi

if [[ -z "${S_Method}" ]]; then
  S_Method="aes-256-gcm"
fi

if [[ -z "${S_PW}" ]]; then
  S_PW="herokushadow"
fi

date -R

mkdir /var/tmp/nginx
mkdir /wwwroot
SYS_Bit="$(getconf LONG_BIT)"

CONF1=$(cat /home/Software/1.conf)
CONF2=$(cat /home/Software/2.conf)
CONF3=$(cat /home/Software/3.conf)
echo -e -n "${CONF1}" > /etc/nginx/conf.d/default.conf
echo -e -n "${S_Path}" >> /etc/nginx/conf.d/default.conf
echo -e -n "${CONF2}" >> /etc/nginx/conf.d/default.conf
echo -e -n "${V2_Path}" >> /etc/nginx/conf.d/default.conf
echo -e -n "${CONF3}" >> /etc/nginx/conf.d/default.conf

sed -i -E "s/Docker_PORT/${PORT}/" /etc/nginx/conf.d/*.conf
sed -i -E "s/^;listen.owner = .*/listen.owner = $(whoami)/" /etc/php7/php-fpm.d/www.conf
sed -i -E "s/^user = .*/user = $(whoami)/" /etc/php7/php-fpm.d/www.conf
sed -i -E "s/^group = (.*)/;group = \1/" /etc/php7/php-fpm.d/www.conf
sed -i -E "s/^user .*/user $(whoami);/" /etc/nginx/nginx.conf

cat <<-EOF > /home/Software/config.json
{  
    "log": {
        "access": "/wwwroot/v2.log",
        "error": "/home/Software/error.log",
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": 9000,
            "protocol": "shadowsocks",
            "settings": {
                "ota": false,
                "network": "tcp,udp",
                "method": "${S_Method}",
                "password": "${S_PW}",
                "level": 1
            },
            "tag": "ss-lod",
            "streamSettings": {
                "network": "domainsocket"
            }
        },
        {
            "port": 8085,
            "listen": "127.0.0.1",
            "protocol": "dokodemo-door",
            "settings": {
                "address": "v1.mux.cool",
                "followRedirect": false,
                "network": "tcp"
            },
            "tag": "ws_ss-in",
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "path": "${S_Path}"
                }
            }
        },
        {
            "port": 2333,
            "listen": "0.0.0.0",
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}",
                        "level": 1,
                        "alterId":${AlterID}
                    }
                ]
            },
            "tag": "ws_tls-in",
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "path": "${V2_Path}"
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls"
                ]
            }
        }
    ],
    "outbounds": [
        {
            "tag": "direct",
            "protocol": "freedom",
            "settings": {}
        },
        {
            "tag": "block",
            "protocol": "blackhole",
            "settings": {}
        },
        {
            "protocol": "freedom",
            "tag": "ssmux",
            "streamSettings": {
                "network": "domainsocket"
            }
        }
    ],
    "transport": {
        "dsSettings": {
            "path": "/home/Software/ss-loop.sock"
        }
    },
    "routing": {
        "domainStrategy": "AsIs",
        "rules": [
           {
                "type": "field",
                "inboundTag": [
                    "ws_ss-in"
                ],
                "outboundTag": "ssmux"
            },
            {
                "type": "field",
                "ip": [
                    "geoip:private"
                ],
                "outboundTag": "block"
            },
            {
                "type": "field",
                "protocol": [
                    "bittorrent"
                ],
                "outboundTag": "block"
            }
        ]
    },
    "policy": {
        "levels": {
            "1": {
                "handshake": 10,
                "connIdle": 300,
                "uplinkOnly": 0,
                "downlinkOnly": 0,
                "bufferSize": 0
            }
        }
    }
}
EOF

wget --no-check-certificate -qO '/tmp/demo.tar.gz' "https://raw.githubusercontent.com/Dark11296/LNPX-core/master/demo.tar.gz"

if [ "$VER" = "latest" ]; then
  V_VER="$(curl -H "Accept: application/json" -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:74.0) Gecko/20100101 Firefox/74.0" -s "https://api.github.com/repos/v2fly/v2ray-core/releases/latest" --connect-timeout 10| grep 'tag_name' | cut -d\" -f4)"
else
  V_VER="v$VER"
fi

wget --no-check-certificate -qO '/tmp/v2ray.zip' "https://github.com/v2fly/v2ray-core/releases/download/$V_VER/v2ray-linux-$SYS_Bit.zip"
unzip /tmp/v2ray.zip v2ray v2ctl geosite.dat geoip.dat -d /home/Software/
rm -rf /tmp/v2ray.zip
tar xvf /tmp/demo.tar.gz -C /wwwroot
rm -rf /tmp/demo.tar.gz
chmod +x /home/Software/*

supervisord --nodaemon --configuration /etc/supervisord.conf
