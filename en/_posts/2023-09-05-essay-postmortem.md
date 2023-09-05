---
layout: post
title: "Making a video essay"
subtitle: "Everything i wish i knew before i actually made one"
lang: en
---

I have recently released my [first video
essay](https://www.youtube.com/watch?v=LekhueQ4zVU)! Unsurprisingly, it's about
monads. :)

<div style="display: flex; justify-content: center; padding: 10px 0 30px 0">
<div style="width: 100%; padding-top: 56.25%; position: relative; overflow: hidden">
<iframe style="position: absolute; top: 0; left: 0; bottom: 0; right: 0; width: 100%; height: 100%" src="https://www.youtube-nocookie.com/embed/LekhueQ4zVU?si=xxnESOW7H1lEiKw7" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
</div>
</div>

Making a video about it rather than a blog post was a choice i made almost a
year ago: i wanted to learn something new, i wanted to try something
different. I started this journey basically from scratch: no knowledge of video
editing, no microphone, no nothing. Looking at the result now, i am conflicted:
on one hand i'm happy i have actually finished a project, instead of quietly
abandoning it like i have done with so many others; on the other, now that i
have a better understanding of what goes into making an essay like this, *i see
so many mistakes in the end product*.

This is why i want to write this. The goal of this post is to collect a list of
observations about the process, what went right, what went wrong, both so that i
can refer to it when i work on the next one, and on the off chance it might
prove useful to someone else.

## Writing process

The closest thing to a video essay i had experience with before starting was
talks, presentations, classes. Their structure is very similar to the one of an
essay: there is an overall point i'm trying to make and argue for, there are
pieces of information i'd like to impart along the way, usually in support of
said point, and there is some accompanying visual material: slides.

When writing a talk, slides tend to be at the center of my writing process: they
dictate the *rhythm* of the presentation. What i actually say over them is not
crucial: as long as i make the point i want to make, the exact words do not
matter too much.

But, and this is a lesson i had to learn: stumbling over one's words is much
more tolerable in a live setting, in which there's no way to do a second
take. For a YouTube video, recorded in the comfort of home... leaving mistakes
in is simply not acceptable.

And, well, i have a bit of a speech impediment: i stammer a bit, and often trip
over my own words. Every line in the final essay had to be recorded at least
twice (and often more) to get one good take... To reduce this, when re-recording
the voice-over sections, i used a fully written script instead. Reading text,
rather than trying to come up with good sentences on the fly, significantly
improved the quality of the lines, and reduced the number of errors. It also
made writing closed captioning easier, since i already had most of the text.

So, first lesson learned: i need to <span class="key">write a full script, and
perhaps use a prompter</span>. It is not enough to just plan the outline, get in
front of the camera, and improvise.

## Writing block and scheduling

However, i found it difficult to write down every sentence i was planning to say
ahead of time. Most of the script i actually wrote *after shooting the live
sections*, when recording the lines over the slides, on the fly. A main reason
why is that i was struggling to put things in writing before doing at least one
live recording, before i could get a feel for the flow of it. I tried to use
Google Docs' speech recognition tool to do a test recording, and use the
transcript, but the result wasn't really usable.

What unblocked me was to do a real recording, in front of the camera. That's
when i spotted a lot of issues, identified what needed work, found the
flow. Unfortunately, due to some time constraints, _that recording ended up
being the only recording session_, meaning that every bit of live video in the
final product _is from the draft_. You might notice that there are more pauses,
more hesitations in some of the live sections: that's why.

So, moving forward, one big lesson: <span class="key">start by recording a real
draft</span>. It can be used to identify problems, unblock the script writing
process... It provides a base, that can be even be used to do a draft of the
editing. But, if recording a draft is one of the earliest things to do; <span
class="key">filming the live sections comes last</span>. Video clips are the
hardest part to fix after the fact: the slides, the voice over, the editing,
everything can be changed at the last minute. But live sections require make-up,
lighting, set-up... So they should be done last, when the script is set, to
avoid needing reshoots or aggressive cuts.

## Video

I do not have a dedicated camera, so i used my phone. Specifically, i used
[DroidCam OBS](https://www.dev47apps.com/obs/) to use my phone as a video source
in [OBS](https://obsproject.com/) on my computer. The upside was that i didn't
have to record everything on my phone, transfer it, and look at the result: i
have direct visual feedback on my computer screen, and can pause / restart the
recording without having to touch my phone. Overall, this worked pretty well,
and i have no major takeaway here, beyond: it works. <span class="key">A phone
is good enough for the video</span>.

There are, however, two limitations i need to investigate for next time:
- the feed was not a steady 60FPS, and some frame drops can be noticed in the
  final video; this is probably because i was connecting to OBS _over WiFi
  instead of USB_, so this might prove to be easy to fix;
- with this solution i can only record in 1080p; the problem with this is that
  my final output is also in 1080p, meaning that any zoom / cropping of the
  recording visibly reduces the quality of the output; this can be observed in
  the essay, but is not shocking, but is nonetheless worth investigating moving
  forward.

Specifically, what i've done is to film from further afar than needed, to avoid
problems of focus: my two first attempts at recording were lost because of that:
in the first, my phone focused on the background, in the second the phone
focused on my face and blurred the background. Filming from slightly afar gave a
better result, worked better with the light, and i just zoomed the footage a bit
during the editing. It might prove better to run experiments there as well to
see if i can use the optical zoom of my phone to achieve the same effect without
sacrificing the output resolution.

So, here, an obvious takeaway: <span class="key">take short test footage to test
the parameters</span>, instead of doing what i did and realizing after 45
minutes of recording that i am out of focus in the footage...

## Audio

Good audio is primordial. It is commonly known that users can tolerate bad video
quality, but won't tolerate bad audio. I have invested in a decent _dynamic_
microphone, with the idea that it would reduce the amount of background noise
that would be picked up compared to a _condenser_ microphone. I don't know
enough about the topic to know for sure if that was the correct decision; but
the result, as far as my untrained ears can tell, is pretty decent: the
voice-over sections sound pretty good: <span class="key">investing into a good
microphone is worth it</span>.

However, a downside of the particular microphone i've chosen: it has quite a
short range. In the live sections, it is _slightly too far_ compared to my setup
during the voice-over sections, and the sound comes out a bit worse. There
again, it should go without saying, but i seem to need the reminder: i should
<span class="key">take short test footage to test the audio as well</span>.

Two other improvements i'll attempt for the next video:
- use [Audacity](https://www.audacityteam.org/) instead of OBS to record voice
  clips, at least for the voice-over sections, to have more control over the
  result (i've noticed some weird artefacts in some places that i suspect might
  have come from the mixing in OBS?)
- i will <span class="key">invest in a pop filter</span>: i've
  noticed that the plosives are very noticeable in some sections; i might not be
  able to use it in the live sections if i want my face to remain visible, but
  since my content is primarily voice-over it would make a difference where it
  matters.

## Editing

I've been using [DaVinci Resolve
18](https://www.blackmagicdesign.com/products/davinciresolve). I had no prior
experience with it, and i didn't have any experience with any other editing
software either, so it's hard for me to offer a detailed review, but: it's free,
it works great, it does much more than what i needed.

However, there's one thing that's been pointed out to me that i can relay and
emphasize here: for live sections, <span class="key">avoid cross fades</span>. I
think there's only one left that i forgot to remove, at the very
beginning. Nothing wrong with them on a technical level, but that's not what's
considered elegant nowadays as far as YouTube editing goes.

A small detail: it's better to organize all the files that end up in the project
(video clips, audio clips, images, sound effects...) under one given folder,
rather than using them where they are, scattered across the drive, it makes
making back-ups easier. There again, it feels obvious in hindsight, but...

## Accessibility

Something extremely important to do on the YouTube side of things: <span
class="key">always include close captioning</span>. Exporting the script as a
text file and feeding it to YouTube works surprisingly well as far as timing is
concerned. The way it cuts sentences, however, is abysmal, and it took me
several hours of work to get them in a good state. I'll try next time to format
the file differently to see if i can make the YouTube editor do the right thing
on the first try.

Two other important accessibility notes that came up in the comments:
- <span class="key">include a warning if the video contains flashing
  lights</span>, which feels obvious, and yet is often forgotten;
- <span class="key">avoid _only_ using colors to convey information</span>:
  information on screen should also be readable by colorblind folks.

## Beyond

This was a first attempt, and while i've learned a lot in the process, i now
better realize _how little i know_, and how much more i have to learn. But, the
essay was overall a success: small audience, as can be expected for Haskell
content from a previously unknown source, but positive feedback. I think the
most important takeaway of all is that <span class="key">you don't need a lot of
resources to get started</span>. I used my phone, free editing software... the
only purchases were a decent microphone (that i needed anyway, since i'm a
remote worker, and i don't want to inflict a sub-par microphone on my
co-workers) and a simple ring light / phone mount. If you've been wanting to try
your hand at making video essays, but weren't sure you were cut out for it, i
hope that the example of me somehow managing to get something out while only
having only draft video footage will convince you to give it a try. :)

I'll try to apply all of those lessons to the next videos. I have a few ideas
for what's next, but nothing concrete yet. I hope this brief "postmortem" / look
behind the scenes was interesting, ~~and remember to like, share, and subscribe!~~
