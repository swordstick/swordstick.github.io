# Bash Code Template
{% highlight bash %}

{% endhighlight %}

# SQL Code Template
{% highlight sql %}

{% endhighlight %}

# PHP Code Template
{% highlight php %}

{% endhighlight %}

# Python Code Template
{% highlight python %}

{% endhighlight %}

# Cpp Code Template
{% highlight cpp %}

{% endhighlight %}

# Href Template
<a href="" target="_blank"></a>

# Img Template
<img src="" title="" height="16px" width="16px" border="0" alt=""/>

# Hr Template
***

# Special character, middle bracket.
「」

# HTML Comments Template.
<!--  -->

# Git reset.
git reset --hard <commit_id>
git push origin HEAD --force

# Git delete branch.
git branch -d the_local_branch
git push origin :the_remote_branch

# Replace highlighter to rouge
sed -i '' 's/{% endhighlight %}/```/' *.md
sed -i '' 's/{% highlight bash %}/``` bash/' *.md
sed -i '' 's/{% highlight sql %}/``` bash/' *.md
sed -i '' 's/{% highlight python %}/``` python/' *.md
sed -i '' 's/{% highlight lua %}/``` lua/' *.md
sed -i '' 's/{% highlight cpp %}/``` cpp/' *.md
sed -i '' 's/{% highlight php %}/``` php/' *.md
sed -i '' 's/{% highlight css %}/``` css/' *.md
grep endhighlight ./*
grep highlight ./*

# Footnotes
[^1]
[^1]: [关于离线，离线官网](https://the-offline.com/about)

# Copyright info
©

# Interval
·
