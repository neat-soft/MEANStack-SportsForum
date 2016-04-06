/*
* This plugin shows the comment count for each post.
* In order to find the post url we search for common Blogger element classes or our own.
*/

function getPostsContainer() {
  var blogs = document.getElementsByClassName('Blog');
  return blogs[0];
}

function makeCountLinks(post) {
  var elems = post.getElementsByTagName('*')
    , links = []
    , commentLinks = []
    , title = null
    , url = null
    , tss = [];
  for (var j = 0; j < elems.length; j++) {

    // get url from timestamp
    if (hasClass(elems[j], 'post-timestamp')) {
      tss.push(elems[j]);
      if (!url) {
        var ts = elems[j];
        var tsl = ts.getElementsByTagName('a');
        for (var k = 0; k < tsl.length && !url; k++) {
          if (hasClass(tsl[k], 'timestamp-link')) {
            url = tsl[k].href;
          }
        }
      }
    }

    if (hasClass(elems[j], 'post-comment-link') || hasClass(elems[j], 'burnzone-comment-link'))
      links.push(elems[j]);
    if (hasClass(elems[j], 'comment-link'))
      commentLinks.push(elems[j]);
    if (hasClass(elems[j], 'entry-title') || hasClass(elems[j], 'post-title') || hasClass(elems[j], 'burnzone-post-url'))
      title = elems[j];
  }

  if (!url) {
    // get url from the title
    if (title) {
      var titleLinks = title.getElementsByTagName('a');
      for (var i = 0; i < titleLinks.length && !url; i++)
        url = titleLinks[i].href;
    }
  }
  
  if (!url)
    return; //bail

  for (var i = 0; i < links.length; i++) {
    var cvstCounter = document.createElement('a');
    cvstCounter.setAttribute('href', url);
    cvstCounter.setAttribute('data-conversation-url', url);
    links[i].innerHTML = '';
    links[i].appendChild(cvstCounter);
  }
  if (links.length == 0) {
    // insert as a sibling of .comment-link
    for (var i = 0; i < commentLinks.length; i++) {
      var parent = commentLinks[i].parentNode;
      var cvstCounter = document.createElement('a');
      cvstCounter.setAttribute('href', url);
      cvstCounter.setAttribute('data-conversation-url', url);
      parent.insertBefore(cvstCounter, commentLinks[i]);
    }
    if (commentLinks.length == 0) {
      // insert next to the timestamp
      for (var i = 0; i < tss.length; i++) {
        var cvstCounter = document.createElement('a');
        cvstCounter.setAttribute('href', url);
        cvstCounter.setAttribute('data-conversation-url', url);
        tss[i].appendChild(cvstCounter);
      }
    }
  }
}

function hasClass(elem, name) {
  var rgx = new RegExp("(^|\\s)" + name + "(\\s|$)");
  return rgx.test(elem.className);
}

var mainBlock = getPostsContainer();
if (!mainBlock)
  return;
var posts = mainBlock.getElementsByTagName("div");
for (var i = 0; i < posts.length; i++) {
  var post = posts[i];
  if (hasClass(post, "post") || hasClass(post, "hentry")) {
    makeCountLinks(post);
  }
}
var cvst_comm_count = document.createElement('script');
cvst_comm_count.type = 'text/javascript';
cvst_comm_count.src = '{{{host}}}/web/js/counts.js';
(document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(cvst_comm_count);
