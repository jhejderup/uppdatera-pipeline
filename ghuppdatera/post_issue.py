from github import Github
import sys

###              [0]         [1]       [2]        [3]       [4]
### python3 post_issue.py report.md owner/repo  pr_url  pr_number
###

g = Github("<your_github_app_id>")

repo = g.get_repo(sys.argv[2])

with open(sys.argv[1], 'r') as myfile:
  data = myfile.read()

data_url = data.replace("<google_forms_url>","<google_forms_url>" + sys.argv[3])


pr = repo.get_pull(int(sys.argv[4]))

if pr.merged_at is not None and pr.state is not 'closed':
  pr_comment = pr.create_issue_comment(body=data_url)
  f = open("ISSUE_URL","w+")
  f.write(pr_comment.url + "\n")
  f.write(pr_comment.html_url)
  f.close()
else:
  f = open("ISSUE_CLOSED","w+")
  f.write((pr.merged_at or "NoneType") + "\n")
  f.write(pr.state or "NoneType")
  f.close()



