# DBをメンテナンスする
vacuumdb -v -z -a -U postgres -h db-container
reindexdb --concurrently -v -d Implem.Pleasanter -U postgres -h db-container
