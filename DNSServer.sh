#!/bin/bash
validar_ip (){
    local ip="$1"
    local regex="^((25[0-4]|2[0-4][0-9]|1?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?))$"

    if [[ $ip =~ $regex ]]; then
        return 0   #True
    else
        return 1   #False
    fi
}

validar_dominio () {
    local dominio="$1"
    local regex="^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$"

    if [[ $dominio =~ $regex ]]; then
        return 0  #True
    else
        return 1  #False
    fi
}

echo "Bienvenido a la configuración de tu servidor DNS"

# Pedir dominio hasta que sea válido
until validar_dominio "$dominio"; do
    echo "Introduce el nombre de dominio que deseas configurar:"
    read dominio

    if validar_dominio "$dominio"; then
        echo "Dominio válido: $dominio"
    else
        echo "Dominio inválido. Intenta de nuevo."
    fi
done

# Pedir IP hasta que sea válida
until validar_ip "$ip"; do
    echo "Introduce la dirección IP de tu servidor DNS:"
    read ip

    if validar_ip "$ip"; then
        echo "IP válida: $ip"
    else
        echo "IP inválida. Intenta de nuevo."
    fi
done

#Editar resolv.conf para fijar la IP en el servidor DNS
sudo sed -i "/^search /c\search $dominio" /etc/resolv.conf    #Utilizo sed -i para modificar especificamente esa linea
sudo sed -i "/^nameserver /c\nameserver $ip" /etc/resolv.conf
echo "Fijando la IP $ip para el servidor DNS"

#Fijar una IP en netplan
echo "network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      addresses: [$ip/24]
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]" | sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null

echo "Fijando la IP $ip en netplan"

#Aplicar cambios
sudo netplan apply
echo "Aplicando cambios en netplan"

#Instalar bind9
echo "Instalando bind9"
sudo apt-get install bind9 bind9utils bind9-doc
sudo apt-get install dnsutils

#Editar named.conf.local para las zonas
echo "Configurando zonas"
sudo tee -a /etc/bind/named.conf.local > /dev/null <<EOF
zone "$dominio" {
    type master;
    file "/etc/bind/db.$dominio";
};

zone "$(echo $ip | awk -F. '{print $3"."$2"."$1}').in-addr.arpa" {
    type master;
    file "/etc/bind/db.$(echo $ip | awk -F. '{print $3"."$2"."$1}')";
};
EOF

#Crear zona directa
echo "Creando zona directa"
sudo tee /etc/bind/db.$dominio > /dev/null <<EOF
\$TTL    604800
@       IN      SOA     $dominio. root.$dominio. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      $dominio.
@       IN      A       $ip
www     IN      CNAME   $dominio.
EOF

#Crear zona inversa
echo "Creando zona inversa"
sudo tee /etc/bind/db.$(echo $ip | awk -F. '{print $3"."$2"."$1}') > /dev/null <<EOF
\$TTL    604800
@       IN      SOA     $dominio. root.$dominio. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      $dominio.
$(echo $ip | awk -F. '{print $4}')     IN      PTR     $dominio.
EOF


#Reiniciar bind9
echo "Reiniciando bind9"
sudo systemctl restart bind9
echo "Configuración finalizada :)"