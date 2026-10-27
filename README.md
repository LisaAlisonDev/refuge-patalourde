# Refuge Patalourde

Site vitrine de l'association Refuge Patalourde (La Réunion) : présentation des animaux à l'adoption, mot du président, témoignages et informations pratiques.

Pour le lancer en local : `python3 -m http.server` puis ouvrir http://localhost:8000

Pour le déployer : `surge .` (site statique, aucune compilation nécessaire).

La page utilise `data/animaux-public.json`, un export léger des animaux disponibles. Lorsqu'ils changent, mettre à jour cet export depuis `data/animaux.json` en ne conservant que les champs affichés par le site.
