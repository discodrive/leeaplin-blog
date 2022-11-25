Output ../public/cloudfront-distros.gif

Set FontSize 24
Set Width 1200
Set Height 600

Type "aws cloudfront list-distributions --query 'DistributionList.Items[*].[Id,Origins.Items[0].Id]' --output text --profile viff | fzf"  Sleep 500ms  Enter
Up@250ms 2
Sleep 5s
