# VMSS y pruebas P2

El VMSS de laboratorio utiliza Standard_B2as_v2, dos instancias de base en las zonas 2 y 3, y hasta tres instancias en el perfil normal. El perfil de calibración de P1 fija temporalmente la capacidad a una instancia. Coordinar los umbrales y las pruebas de carga con Sebastián.

## Integración

compute_autoscale.tf usa los recursos de red azurerm_subnet.app, azurerm_lb_probe.app, azurerm_lb_backend_address_pool.app, azurerm_subnet_network_security_group_association.app y azurerm_lb_outbound_rule.agent, además de azurerm_resource_group.rg. Se requiere la clave SSH pública vmss_admin_public_key y las variables de proyecto de la base. El VMSS inyecta el nombre de azurerm_key_vault.kv en app/cloud-init.yaml. Confirmar los identificadores con la rama de infraestructura de Luis.

## Evidencias P2

En cada corrida partir de dos instancias sanas y coordinar carga moderada con Sebastián. Para la prueba lógica, ejecutar fail-health.sh mediante Run Command sobre una sola instancia y registrar UTC, HTTP 503, exclusión, errores y recuperación. Si la recuperación es manual, ejecutar restore-health.sh y registrar ese mecanismo. Para la prueba abrupta, usar una corrida independiente y eliminar una sola instancia del VMSS de laboratorio. Esperar a que se recupere la capacidad antes de cerrar la prueba.

jesus-evidencias.ps1 exporta reglas, NIC, zonas, sonda, reparación y actividad. Pasar los nombres reales del NSG, balanceador y sonda si difieren de los valores por defecto. Registrar las ventanas y los datos de Locust en P2-ventanas-plantilla.csv y adjuntar la métrica Health Probe Status del balanceador. Revisar las salidas antes de publicar datos del laboratorio.
