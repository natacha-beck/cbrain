find ./views -type f -name "*.yml" | while read -r file; do
  sed -e 's/"Bourreaux/"Serveurs de calcul/g' \
      -e 's/"bourreaux/"serveurs de calcul/g' \
      -e 's/"Bourreau/"Serveur de calcul/g' \
      -e 's/"bourreau/"serveur de calcul/g' "$file" > "${file}.tmp"
  
  cat "${file}.tmp" > "$file"
  rm "${file}.tmp"
done
