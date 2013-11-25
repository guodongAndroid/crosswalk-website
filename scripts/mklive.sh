desc="Generate live version of website"
function run () {
    debug=${debug:=0}
    
    check_perms
    
    #
    # Verify this tree is on the 'master' branch
    #
    git branch | grep -q '\* master' || {
        echo ""
        echo "mklive.sh can only be run in the 'master' branch."
        echo "$ git checkout master"
        echo ""
        exit
    }
    
    [ "$1" != "-f" ] && check_unstaged
    cd wiki
    [ "$1" != "-f" ] && check_unstaged
    cd ..
    
    debug_msg "Check complete." 
    
    # Make sure that 'wiki' contains a full checkout
    cd wiki
    git checkout -f || { 
        die "Could not checkout wiki"
    }
    cd ..
    
    # Make new branch for live-YYYYMMDD
    # -t track upstream (push/pull from github will work)
    # -f force -- delete branch if it already exists
    branch=live-$(date +%Y%m%d)
    iter=1
    while git show-ref --verify --quiet refs/heads/${branch} || 
          git show-ref --verify --quiet refs/remotes/origin/${branch}; do
        branch="${branch/.*}.${iter}"
        iter=$((iter+1))
    done
    echo "Using branch: ${branch}"
    git branch -t ${branch}
    git checkout ${branch}
    
    debug_msg "Branch / Checkout to ${branch} complete."
    
    #
    # Nuke all dynamic content and regenerate it
    #
    ./site.sh cleanup
    debug_msg "Cleanup complete."
    ./site.sh generate
    debug_msg "Generate complete."
    
    #
    # Turn off the PHP script override for the root directory
    # by commenting out the RewriteCond and Rule 
    #
    sed -i \
        -e 's/^\(.*RewriteCond %{REQUEST_FILENAME}\.php -f\)$/#\1/' \
        -e 's/^\(.*RewriteRule .* %{REQUEST_URI}\$1\.php \[L\]\)$/#\1/' \
        .htaccess
    
    #
    # Modify .gitignore to track/manage the generated content
    # from under the wiki/ path
    #
    sed -i -e 's:^wiki/\*\.html:#wiki/*.html:' \
           -e 's:^wiki/assets:#wiki/assets:' \
           -e 's:^wiki/documentation:#wiki/documentation:' \
           -e 's:^wiki/contribute:#wiki/contribute:' .gitignore
    for i in xwalk.css markdown.css menus.js; do
        sed -i -e s:^${i}:#${i}: .gitignore
    done
    
    #
    # Adding generated Wiki content to the Live site
    #
    find wiki -name '*html' -exec git add {} \;
    find wiki/assets -exec git add {} \;
    git add xwalk.css
    git add markdown.css
    git add menus.js
    
    debug_msg "git add complete." 
    
    #
    # Remove PHP generating scripts from Live site
    #
    for file in xwalk markdown; do
        for extension in msg css.php scss css.map; do
            [ -e ${file}.${extension} ] && rm ${file}.${extension}
        done
    done
    [ -e menus.js.php ] && rm menus.js.php
    #
    # Remove bash scripts from the Live site
    rm *.sh
    
    #
    # Remove all Wiki markdown content from Live site
    #
    find wiki -name '*.md' -exec rm {} \;
    find wiki -name '*.mediawiki' -exec rm {} \;
    find wiki -name '*.org' -exec rm {} \;
    debug_msg "Markdown content removal complete."
    
    git commit -s -a -m "Automatic static version commit for ${branch}"
    
    git checkout master
    git tag tag-${branch}
    debug_msg "Site checkout complete."
    
    cd wiki
    git checkout -f
    git tag tag-${branch}
    debug_msg "Wiki checkout complete."
    cd ..
    
cat << EOF

Changes committed to git as branch ${branch}.

Current tree set back to 'master'. Steps to take:

  1. Push ${branch} to staging server:
  
     ./site.sh push
  
  2. Test the site by going to https://stg.crosswalk-project.org
     2.1 Visit each category section. Make sure they work.
         https://stg.crosswalk-project.org/#documentation
         https://stg.crosswalk-project.org/#contribute
         https://stg.crosswalk-project.org/#wiki
     2.2 Check the Wiki History and verify the newest changes exist
         https://stg.crosswalk-project.org/#wiki/history
  
  3. Resize your browser window down to a width of 320 and up to 
     full screen. Ensure responsize design still functions.

  4. After you are confident that the site is good, push the version
     from the Staging server to the Live server:
     
    ./site.sh push live
    
EOF
}
