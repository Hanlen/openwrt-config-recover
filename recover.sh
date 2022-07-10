#!/bin/bash

#env
g_backup=/tmp/backup
g_etc=${g_backup}/etc

g_backup2=/tmp/backup2

function backupAndRecover()
{
  src=$1
  dest=$2
  backup_flag=$3

  is_link=`file ${src} | grep symbolic`
  if [ -n "${is_link}" ]; then
    return
  fi

  if [ ${backup_flag} -eq 1 ]; then
    p=`dirname ${dest}`
    backup_dir=${g_backup2}${p}
    if [ ! -d ${backup_dir} ]; then
      mkdir -p ${backup_dir}
    fi
    cp -rf ${dest} ${backup_dir}
  fi

  if [ -f ${src} ]; then
    cp -r ${src} ${dest}
  fi
}

function update_opkg() 
{
  mv /etc/opkg/customfeeds.conf /etc/opkg/customfeeds.conf.bak
  echo "src/gz openwrt_kiddin9 https://op.supes.top/packages/aarch64_generic" > /etc/opkg/customfeeds.conf
  # TODO: remove check_signature
  opkg update
}

function init() 
{
  update_opkg;
  #ld link
  ln -s /lib/ld-musl-aarch64.so.1 /lib/ld-linux-aarch64.so.1
}

function install_apps()
{
  opkg install zsh git-http vim luci-app-baidupcs-web luci-app-n2n gcc

  #oh-my-zsh
  sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git  ~/.oh-my-zsh/plugins/zsh-syntax-highlighting
  echo "source ~/.oh-my-zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ~/.zshrc
  git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
  #TODO: add autosuggestions to zshrc

  echo "alias vi='vim'" > ~/.zshrc
}

function custom_recover()
{
  pushd ${g_backup}
  directories=`ls -a ${g_backup}`
  for i in ${directories} ; do
    if [[ ${i} == "etc" ]] || [[ ${i} == ".." ]] || [[ ${i} == "." ]]; then
      continue
    fi

    if [ ! -d /${i} ]; then
      mkdir -p /${i}
    fi
    cp $i/* /${i} -rf
  done
  popd
}

function recover_etc()
{
  #crontab
  backupAndRecover ${g_etc}/crontabs/root /etc/crontabs/root 1

  #network
  #backupAndRecover ${g_etc}/config/network /etc/config/network 1
  #firewall
  #backupAndRecover ${g_etc}/config/firewall /etc/config/firewall 1
  #dnsmasq
  backupAndRecover ${g_etc}/config/dnsmasq.conf /etc/config/dnsmasq.conf 1
  #nginx
  #backupAndRecover ${g_etc}/config/nginx /etc/config/nginx 1

  #user
  backupAndRecover ${g_etc}/passwd /etc/passwd 1
  backupAndRecover ${g_etc}/group /etc/group 1
  backupAndRecover ${g_etc}/shadow /etc/shadow 1

  #qos
  backupAndRecover ${g_etc}/config/eqos /etc/config/eqos 0

  #passwall
  backupAndRecover ${g_etc}/config/passwall /etc/config/passwall 0
  backupAndRecover ${g_etc}/config/passwall_server /etc/config/passwall_server 0
  backupAndRecover ${g_etc}/config/passwall_show /etc/config/passwall_show 0
  #v2ray
  backupAndRecover ${g_etc}/config/v2ray /etc/config/v2ray 0
  backupAndRecover ${g_etc}/v2ray /etc/v2ray 0
  #xray
  backupAndRecover ${g_etc}/config/xray /etc/config/xray 0
  backupAndRecover ${g_etc}/xray /etc/xray 0

  #samba
  backupAndRecover ${g_etc}/config/samba4 /etc/config/samba4 1
  backupAndRecover ${g_etc}/samba /etc/config/samba 1

  #n2n
  backupAndRecover ${g_etc}/config/n2n_v2 /etc/config/n2n_v2 1

  #fullcone
  backupAndRecover ${g_etc}/config/fullcone /etc/config/fullcone 1

  #docker
  backupAndRecover ${g_etc}/config/dockerd /etc/config/dockerd 1

  #baidu
  backupAndRecover ${g_etc}/config/baidupcs-web /etc/config/baidupcs-web 0
  backupAndRecover ${g_etc}/config/baidupcs-web-opkg /etc/config/baidupcs-web-opkg 0

  #autoreboot
  backupAndRecover ${g_etc}/config/autoreboot /etc/config/autoreboot 0

  #aria2
  backupAndRecover ${g_etc}/config/aria2 /etc/config/aria2 1

  #dhcp
  backupAndRecover ${g_etc}/config/dhcp /etc/config/dhcp 1

  #dropbear
  backupAndRecover ${g_etc}/config/dropbear /etc/config/dropbear 1
}

function stop_service()
{
  rm -f /etc/rc.d/K80haproxy /etc/rc.d/S99haproxy
  /etc/init.d/haproxy stop
}

function start_services()
{
  /etc/init.d/passwall start
  /etc/init.d/cron reload
  /etc/init.d/dnsmasq restart

  /etc/init.d/samba4 restart
}

function tar_and_upload()
{
  dir=$1
  password=$2

  pushd ${dir}
  board_model="`cat /etc/board.json| grep "id" | cut -d'"' -f4`"
  tar_file=/tmp/${board_model}-backup-`date +'%Y-%m-%d'`.tar.gz
  tar -czvO * | openssl des3 -salt -k ${password} -out ${tar_file}
  popd
  echo ${tar_file}
  baidupcs-web u "${tar_file}" /
}

function untar()
{
  tar_file=$1
  password=$2

  if [ ! -d ${g_backup} ]; then
    mkdir -p ${g_backup}
  fi
  openssl des3 -d -k ${password} -salt -in ${tar_file} | tar -C ${g_backup} -xzf -
}

function auto_recover()
{
  init
  recover_etc
  stop_service
  start_services
  #recover_root
  install_apps
  custom_recover
  #reboot
}

