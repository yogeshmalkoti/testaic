echo "Content-type: text/html"
echo ""
echo '<html>'
echo '<head>'
echo '<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">'
echo '<title>Hello World</title>'
echo '</head>'
echo '<body>'
echo '<h1>Hello World</h1><p>'
echo 'from AWS<p>'
curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | grep -E "availabilityZone|"privateIp""
echo 'You may get the S3 content from below links.</p>'
echo '<a href="/aicbucket">aicbucket</a></p>'
echo '</body>'
echo '</html>'
exit 0
