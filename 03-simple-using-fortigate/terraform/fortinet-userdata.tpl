#cloud-config

config system admin
    edit admin
        set password adminadmin12!
    next
end

config system interface
    edit "port1"
        set alias "GWLB"
        set mode static
        set allowaccess ping https ssh http
        set defaultgw disable
    next
end

config system geneve
    edit "GWLB-GENEVE"
        set interface "port1"
        set type ppp
        set remote-ip ${geneve_remote_ip}
    next
end

config router static
    edit 1
        set dst 0.0.0.0 0.0.0.0
        set device "GWLB-GENEVE"
        set distance 5
    next
end

config firewall policy
    edit 1
        set name "GWLB-In"
        set srcintf "GWLB-GENEVE"
        set dstintf "port1"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set logtraffic all
    next
    edit 2
        set name "GWLB-Return"
        set srcintf "port1"
        set dstintf "GWLB-GENEVE"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
    next
    edit 3
        set name "GENEVE-Intra"
        set srcintf "GWLB-GENEVE"
        set dstintf "GWLB-GENEVE"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
    next
end

config system interface
    edit "port1"
        set defaultgw disable
    next
end