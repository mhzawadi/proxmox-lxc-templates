<?php
$CONFIG = array (
  'installed' => false,
  'serverid' => 1,
  'trusted_domains' => [
    '##HOSTIP##'
  ],
  'overwrite.cli.url' => 'http://##HOSTIP##',
  'datadirectory' => '/var/lib/nextcloud/',
  'dbtype' => 'sqlite3',
  'dbtableprefix' => 'oc_',
  'htaccess.IgnoreFrontController' => true,
  'htaccess.RewriteBase' => '/',
  'loglevel' => 2,
  'overwriteprotocol' => 'http',
);
